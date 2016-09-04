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

my $convert_string_to_seconds = sub {
    my $input   = $_[0];
    my $measure = chop($input);

    my $unit = CACHE_DURATION_CONVERSION->{$measure} ||    #
        carp
        "Unknown duration unit: $measure, valid options are Xs, Xm, Xh, Xd, XM or Xy";

    carp "Initial duration start (currently: $input) must be an integer"
        unless $input =~ /^\d+$/;

    return $unit * $input;
};

=head1 NAME

CatalystX::Fastly::Role::Response - Methods for Fastly intergration to Catalyst

=head1 SYNOPTIS

    package MyApp;

    ...

    use Catalyst qw/
        ConfigLoader
        +MooseX::Fastly::Role
        +CatalystX::Fastly::Role::Response
      /;

    extends 'Catalyst';

    ...

    package MyApp::Controller::Root

    sub a_page :Path('some_page') {
        my ( $self, $c ) = @_;

        $c->cdn_max_age('10d');
        $c->browser_max_age('1d');

        $c->add_surrogate_key('FOO','WIBBLE');

        $c->purge_surrogate_key('BAR');

        $c->response->body( 'Add cache and surrogate key headers, and purge' );
    }

=head1 DESCRIPTION

This role adds methods to Catalyst relating to use of a Content
Distribution Network (CDN) and/or Cacheing proxy. It is specifically targeted
at L<Fastly|https://www.fastly.com> but hopefully others could use it as a
template for other CDN's in future.

Values are converted and headers set in C<finalize_headers>, this is
also when any purges take place.

=head1 CDN METHODS

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

=head2 cdn_stale_while_revalidate

  $c->cdn_stale_while_revalidate('1y');

Applied to B<Surrogate-Control> only when L</cdn_max_age> is set, this
informs the CDN how long to continue serving stale content from cache while
it is revalidating in the background.

=cut

has cdn_stale_while_revalidate => (
    is  => 'rw',
    isa => 'Maybe[Str]',
);

=head2 cdn_stale_if_error

  $c->cdn_stale_if_error('1y');

Applied to B<Surrogate-Control> only when L</cdn_max_age> is set, this
informs the CDN how long to continue serving stale content from cache
if there is an error at the origin.

=cut

has cdn_stale_if_error => (
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

=head1 BROWSER METHODS

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

=head2 browser_stale_while_revalidate

  $c->browser_stale_while_revalidate('1y');

Applied to B<Cache-Control> only when L</browser_max_age> is set, this
informs the browser how long to continue serving stale content from cache while
it is revalidating fromm the CDN.

=cut

has browser_stale_while_revalidate => (
    is  => 'rw',
    isa => 'Maybe[Str]',
);

=head2 browser_stale_if_error

  $c->browser_stale_if_error('1y');

Applied to B<Cache-Control> only when L</browser_max_age> is set, this
informs the browser how long to continue serving stale content from cache
if there is an error at the CDN.

=cut

has browser_stale_if_error => (
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

=head1 SURROGATE KEY AND PURGE METHODS

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

purge_surrogate_keys are passed to C<cdn_purge_now>

$c->cdn_purge_now( { keys => \@keys, } );

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

=head1 INTERNAL METHODS

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

        my @cache_control;

        push @cache_control, sprintf 'max-age=%s',
            $convert_string_to_seconds->($browser_max_age);

        if ( my $duration = $c->browser_stale_while_revalidate ) {
            push @cache_control, sprintf 'stale-while-revalidate=%s',
                $convert_string_to_seconds->($duration);

        }

        if ( my $duration = $c->browser_stale_if_error ) {
            push @cache_control, sprintf 'stale-if-error=%s',
                $convert_string_to_seconds->($duration);

        }

        $c->res->header( 'Cache-Control' => join( ', ', @cache_control ) );

    }

    # Set the caching at CDN, seperate to what the user's browser does
    # https://docs.fastly.com/guides/tutorials/cache-control-tutorial
    if ( $c->cdn_never_cache ) {

        # Make sure fastly doesn't cache this by accident
        $c->res->header( 'Surrogate-Control' => 'private' );

    } elsif ( my $cdn_max_age = $c->cdn_max_age ) {

        my @surrogate_control;

        push @surrogate_control, sprintf 'max-age=%s',
            $convert_string_to_seconds->($cdn_max_age);

        if ( my $duration = $c->cdn_stale_while_revalidate ) {
            push @surrogate_control, sprintf 'stale-while-revalidate=%s',
                $convert_string_to_seconds->($duration);

        }

        if ( my $duration = $c->cdn_stale_if_error ) {
            push @surrogate_control, sprintf 'stale-if-error=%s',
                $convert_string_to_seconds->($duration);

        }

        $c->res->header(
            'Surrogate-Control' => join( ', ', @surrogate_control ) );

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
        my @keys = $c->surrogate_keys();

        if ( $c->cdn_standardize_surrogate_keys ) {
            @keys = _cdn_standardize_surrogate_keys(@keys);
        }

        my $key_string = join ' ', @keys;
        $c->res->header( 'Surrogate-Key' => $key_string );
    }

}

# Method so could be overwritten if needed
sub _cdn_standardize_surrogate_keys {

    my @keys = map {
        my $key = $_;
        $key =~ s/\W//g;    # Remove all non word characters
        $key = uc $key;     # go upper case
        $key
    } @_;

    return @keys;

}

=head1 SEE ALSO

L<MooseX::Fastly::Role> - provides cdn_purge_now
L<stale-while-validate|https://www.fastly.com/blog/stale-while-revalidate/>

=head1 AUTHOR

Leo Lapworth <LLAP@cpan.org>

=cut

1;
