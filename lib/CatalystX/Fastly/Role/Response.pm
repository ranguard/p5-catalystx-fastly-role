package CatalystX::Fastly::Role::Response;

use Moose::Role;
use Carp;

requires 'cdn_purge_now';

use constant CACHE_DURATION_CONVERSION => {
    s => 1,
    m => 60,
    h => 3600,
    d => 86_400,
    M => 2_628_000,
    y => 31_556_952,
};

=head1 NAME

CatalystX::Fastly::Role::Response - Methods for Fastly intergration to Catalyst

=head1 SYNOPTIS

    package MyApp::Catalyst;

    use Catalyst qw/
        +CatalystX::Fastly::Role::Response
      /;


=head1 DESCRIPTION

This role adds methods to Catalyst relating to use of a Content
Distribution Network (CDN) and/or Cacheing proxy. It is specifically targeted
at L<Fastly|https://www.fastly.com> but hopefully others could use it as a
template for other CDN's in future.

Values are converted and headers set in C<finalize_headers>

=head1 METHODS

=head2 cdn_max_age

  $c->cdn_max_age( '1d' );

Takes Xs, Xm, Xh, Xd, XM or Xy, which is converted into seconds and used to set
B<max-age> in the B<Surrogate-Control> header, which CDN's use to determine how
long to cache for. If not supplied Fastly will use the
B<Cache-Control> headers value (as set by L</browser_max_age>).

=cut

has cdn_max_age => (
    is  => 'rw',
    isa => 'Maybe[Str]',
);

=head2 cdn_never_cache

  $c->cdn_never_cache(1);

When true the B<Surrogate-Control> header will have a value of B<private>,
this forces fastly to never cache the results (even for multiple outstanding
requests), no matter what other options have been set.

=cut

has cdn_never_cache => (
    is      => 'rw',
    isa     => 'Bool',
    default => sub {0},
);

=head2 browser_max_age

  $c->browser_max_age( '1m' );

Takes Xs, Xm, Xh, Xd, XM, Xy, which is converted to seconds and used to
set B<max-age> in the B<Cache-Control> header, browsers use this to
determine how long to cache for.

=cut

has browser_max_age => (
    is  => 'rw',
    isa => 'Maybe[Str]',
);

=head2 browser_never_cache

  $c->browser_never_cache(1);

When true the headers below are set, this forces the browser to never cache
the results. B<private> is NOT added as this would also affect the CDN
even if C<cdn_max_age> was set.

  Cache-Control: no-cache, no-store, must-revalidate, max-age=0, max-stale=0, post-check=0, pre-check=0
  Pragma: no-cache
  Expires: 0

N.b. Some versions of IE won't let you download files, such as a PDF if it is
not allowed to cache it, it is recommended to set a L</browser_max_age>('1m')
in this situation.

IE8 have issues with the above and using the back button, and need an additional I<Vary: *> header,
L<as noted by Fastly|https://docs.fastly.com/guides/debugging/temporarily-disabling-caching>,
this is left for you to impliment.

=cut

has browser_never_cache => (
    is      => 'rw',
    isa     => 'Bool',
    default => sub {0},
);

=head2 add_surrogate_key

  $c->add_surrogate_key('FOO','WIBBLE');

This can be called multiple times, the values will be set
as the B<Surrogate-Key> header as I<`FOO WIBBLE`>.

=cut

has _surrogate_keys => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        add_surrogate_key   => 'push',
        has_surrogate_keys  => 'count',
        surrogate_keys      => 'elements',
        join_surrogate_keys => 'join',
    },
);

=head2 purge_surrogate_key

  $c->purge_surrogate_key('BAR');

=cut

has _surrogate_keys_to_purge => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        purge_surrogate_key          => 'push',
        has_surrogate_keys_to_purge  => 'count',
        surrogate_keys_to_purge      => 'elements',
        join_surrogate_keys_to_purge => 'join',
    },
);

=head2 cdn_standardize_surrogate_keys

  $c->cdn_standardize_surrogate_keys(1);

If set this will case all keys to be upper cased and have
any non-word characters removed.

=cut

has cdn_standardize_surrogate_keys => (
    is      => 'rw',
    isa     => 'Bool',
    default => sub {0},
);

=head2 finalize_headers

The method that actually sets all the headers, should be called
automatically by Catalyst.

=cut

sub finalize_headers {
    my $c = shift;

    # Headers for web browser, Fastly will also use these if
    # no cdn headers have been set.
    if ( $c->browser_never_cache ) {

        $c->res->header( 'Cache-Control' =>
                'no-cache, no-store, must-revalidate, max-age=0, max-stale=0, post-check=0, pre-check=0'
        );
        $c->res->header( 'Pragma'  => 'no-cache' );
        $c->res->header( 'Expires' => '0' );

    } elsif ( my $browser_max_age = $c->browser_max_age ) {

        my $unit = CACHE_DURATION_CONVERSION->{ chop($browser_max_age) } || 1;
        my $max_age = sprintf 'max-age=%s', $unit * $browser_max_age;

        $c->res->header( 'Cache-Control' => $max_age );

    }

    # Set the caching at CDN, seperate to what the user's browser does
    # https://docs.fastly.com/guides/tutorials/cache-control-tutorial
    if ( $c->cdn_never_cache ) {

        # Make sure fastly doesn't cache this by accident
        $c->res->header( 'Surrogate-Control' => 'private' );

    } elsif ( my $cdn_max_age = $c->cdn_max_age ) {

        # TODO: https://www.fastly.com/blog/stale-while-revalidate/
        # Use this value
        my $unit = CACHE_DURATION_CONVERSION->{ chop($cdn_max_age) } || 1;
        my $max_age = sprintf 'max-age=%s', $unit * $cdn_max_age;

        $c->res->header( 'Surrogate-Control' => $max_age );

    }

    # Some action must have triggered a purge
    if ( $c->has_surrogate_keys_to_purge ) {

        # Something changed, means we need to purge some keys
        # All keys are set as UC, with : and -'s removed
        # so make sure our purging is as well
        my @keys = $c->surrogate_keys_to_purge();

        if ( $c->cdn_standardize_surrogate_keys ) {
            @keys = _cdn_standardize_surrogate_keys(@keys);
        }

        $c->cdn_purge_now( { keys => \@keys, } );
    }

    # Surrogate key
    if ( $c->has_surrogate_keys ) {

        # See http://www.fastly.com/blog/surrogate-keys-part-1/
        my @keys = $c->surrogate_keys_to_purge();

        if ( $c->cdn_standardize_surrogate_keys ) {
            @keys = _cdn_standardize_surrogate_keys(@keys);
        }

        my $key_string = join ' ', @keys;
        $c->res->header( 'Surrogate-Key' => $key_string );
    }

}

sub _cdn_standardize_surrogate_keys {
    my @keys = map {
        my $key = $_;
        $key =~ s/\W//g;    # Remove all non word characters
        $key = uc $key;     # go upper case
        $key
    } $@;
    return @keys;

}

1;
