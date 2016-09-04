# NAME

CatalystX::Fastly::Role::Response - Methods for Fastly intergration to Catalyst

# SYNOPTIS

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

# DESCRIPTION

This role adds methods to Catalyst relating to use of a Content
Distribution Network (CDN) and/or Cacheing proxy. It is specifically targeted
at [Fastly](https://www.fastly.com) but hopefully others could use it as a
template for other CDN's in future.

Values are converted and headers set in `finalize_headers`, this is
also when any purges take place.

# METHODS

## cdn\_max\_age

    $c->cdn_max_age( '1d' );

Takes Xs, Xm, Xh, Xd, XM or Xy, which is converted into seconds and used to set
**max-age** in the **Surrogate-Control** header, which CDN's use to determine how
long to cache for. If not supplied Fastly will use the
**Cache-Control** headers value (as set by ["browser\_max\_age"](#browser_max_age)).

## cdn\_stale\_while\_revalidate

    $c->cdn_stale_while_revalidate('1y');

Applied to **Surrogate-Control** only when ["cdn\_max\_age"](#cdn_max_age) is set, this
informs the CDN how long to continue serving stale content from cache while
it is revalidating in the background.

## cdn\_stale\_if\_error

    $c->cdn_stale_if_error('1y');

Applied to **Surrogate-Control** only when ["cdn\_max\_age"](#cdn_max_age) is set, this
informs the CDN how long to continue serving stale content from cache
if there is an error at the origin.

## cdn\_never\_cache

    $c->cdn_never_cache(1);

When true the **Surrogate-Control** header will have a value of **private**,
this forces fastly to never cache the results (even for multiple outstanding
requests), no matter what other options have been set.

## browser\_max\_age

    $c->browser_max_age( '1m' );

Takes Xs, Xm, Xh, Xd, XM, Xy, which is converted to seconds and used to
set **max-age** in the **Cache-Control** header, browsers use this to
determine how long to cache for.

## browser\_never\_cache

    $c->browser_never_cache(1);

When true the headers below are set, this forces the browser to never cache
the results. **private** is NOT added as this would also affect the CDN
even if `cdn_max_age` was set.

    Cache-Control: no-cache, no-store, must-revalidate, max-age=0, max-stale=0, post-check=0, pre-check=0
    Pragma: no-cache
    Expires: 0

N.b. Some versions of IE won't let you download files, such as a PDF if it is
not allowed to cache it, it is recommended to set a ["browser\_max\_age"](#browser_max_age)('1m')
in this situation.

IE8 have issues with the above and using the back button, and need an additional _Vary: \*_ header,
[as noted by Fastly](https://docs.fastly.com/guides/debugging/temporarily-disabling-caching),
this is left for you to impliment.

## browser\_stale\_while\_revalidate

    $c->browser_stale_while_revalidate('1y');

Applied to **Cache-Control** only when ["browser\_max\_age"](#browser_max_age) is set, this
informs the browser how long to continue serving stale content from cache while
it is revalidating fromm the CDN.

## browser\_stale\_if\_error

    $c->browser_stale_if_error('1y');

Applied to **Cache-Control** only when ["browser\_max\_age"](#browser_max_age) is set, this
informs the browser how long to continue serving stale content from cache
if there is an error at the CDN.

## add\_surrogate\_key

    $c->add_surrogate_key('FOO','WIBBLE');

This can be called multiple times, the values will be set
as the **Surrogate-Key** header as _\`FOO WIBBLE\`_.

## purge\_surrogate\_key

    $c->purge_surrogate_key('BAR');

purge\_surrogate\_keys are passed to `cdn_purge_now`

$c->cdn\_purge\_now( { keys => \\@keys, } );

## cdn\_standardize\_surrogate\_keys

    $c->cdn_standardize_surrogate_keys(1);

If set this will case all keys to be upper cased and have
any non-word characters removed.

# INTERNAL METHODS

## finalize\_headers

The method that actually sets all the headers, should be called
automatically by Catalyst.

# SEE ALSO

[MooseX::Fastly::Role](https://metacpan.org/pod/MooseX::Fastly::Role) - provides cdn\_purge\_now
[stale-while-validate](https://www.fastly.com/blog/stale-while-revalidate/)

# AUTHOR

Leo Lapworth <LLAP@cpan.org>
