# NAME

CatalystX::Fastly::Role::Response - Methods for Fastly integration to Catalyst

# SYNOPSIS

```perl
package MyApp;

...

use Catalyst qw/
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

    $c->response->body( 'Add cache and surrogate key headers' );
}
```

# DESCRIPTION

This role adds methods to set appropriate cache headers in Catalyst responses,
relating to use of a Content Distribution Network (CDN) and/or Caching
proxy as well as cache settings for HTTP clients (e.g. web browser). It is
specifically targeted at [Fastly](https://www.fastly.com) but may also be
useful to others.

Values are converted and headers set in `finalize_headers`. Headers
affected are:

- Cache-Control

    HTTP client (e.g. browser) and CDN (if Surrogate-Control not used) cache settings

- Surrogate-Control

    CDN only cache settings

- Surrogate-Key

    CDN only, can then later be used to purge content

- Pragma

    only set for for [browser\_never\_cache](https://metacpan.org/pod/browser_never_cache)

- Expires

    only for [browser\_never\_cache](https://metacpan.org/pod/browser_never_cache)

# TIME PERIOD FORMAT

All time periods are expressed as: `Xs`, `Xm`, `Xh`, `Xd`, `XM` or `Xy`,
e.g. seconds, minutes, hours, days, months or years, e.g. `3h` is three hours.

# CDN METHODS

## cdn\_max\_age

```
$c->cdn_max_age( '1d' );
```

Used to set `max-age` in the `Surrogate-Control` header, which CDN's use
to determine how long to cache for. **If _not_ supplied the CDN will use the
`Cache-Control` headers value** (as set by ["browser\_max\_age"](#browser_max_age)).

## cdn\_stale\_while\_revalidate

```
$c->cdn_stale_while_revalidate('1y');
```

Applied to `Surrogate-Control` only when ["cdn\_max\_age"](#cdn_max_age) is set, this
informs the CDN how long to continue serving stale content from cache while
it is revalidating in the background.

## cdn\_stale\_if\_error

```
$c->cdn_stale_if_error('1y');
```

Applied to `Surrogate-Control` only when ["cdn\_max\_age"](#cdn_max_age) is set, this
informs the CDN how long to continue serving stale content from cache
if there is an error at the origin.

## cdn\_never\_cache

```
$c->cdn_never_cache(1);
```

When true the `Surrogate-Control` header will have a value of `private`,
this forces Fastly (other CDN's may behave differently) to never cache the
results (even for multiple outstanding requests), no matter what other
options have been set.

# BROWSER METHODS

## browser\_max\_age

```
$c->browser_max_age( '1m' );
```

Used to set `max-age` in the `Cache-Control` header, browsers use this to
determine how long to cache for. **The CDN will also use this if there is
no `Surrogate-Control` (as set by ["cdn\_max\_age"](#cdn_max_age))>.**

## browser\_stale\_while\_revalidate

```
$c->browser_stale_while_revalidate('1y');
```

Applied to `Cache-Control` only when ["browser\_max\_age"](#browser_max_age) is set, this
informs the browser how long to continue serving stale content from cache while
it is revalidating from the CDN.

## browser\_stale\_if\_error

```
$c->browser_stale_if_error('1y');
```

Applied to `Cache-Control` only when ["browser\_max\_age"](#browser_max_age) is set, this
informs the browser how long to continue serving stale content from cache
if there is an error at the CDN.

## browser\_never\_cache

```
$c->browser_never_cache(1);
```

When true the headers below are set, this forces the browser to never cache
the results. `private` is NOT added as this would also affect the CDN
even if `cdn_max_age` was set.

```
Cache-Control: no-cache, no-store, must-revalidate, max-age=0, max-stale=0, post-check=0, pre-check=0
Pragma: no-cache
Expires: 0
```

N.b. Some versions of IE won't let you download files, such as a PDF if it is
not allowed to cache it, it is recommended to set a ["browser\_max\_age"](#browser_max_age)('1m')
in this situation.

IE8 have issues with the above and using the back button, and need an additional _Vary: \*_ header,
[as noted by Fastly](https://docs.fastly.com/guides/debugging/temporarily-disabling-caching),
this is left for you to implement.

# SURROGATE KEYS

## add\_surrogate\_key

```
$c->add_surrogate_key('FOO','WIBBLE');
```

This can be called multiple times, the values will be set
as the `Surrogate-Key` header as _\`FOO WIBBLE\`_.

See ["cdn\_purge\_now" in MooseX::Fastly::Role](https://metacpan.org/pod/MooseX%3A%3AFastly%3A%3ARole#cdn_purge_now) if you are
interested in purging these keys!

# INTERNAL METHODS

## finalize\_headers

The method that actually sets all the headers, should be called
automatically by Catalyst.

# SEE ALSO

[MooseX::Fastly::Role](https://metacpan.org/pod/MooseX%3A%3AFastly%3A%3ARole) - provides cdn\_purge\_now and access to [Net::Fastly](https://metacpan.org/pod/Net%3A%3AFastly)
[stale-while-validate](https://www.fastly.com/blog/stale-while-revalidate/)

# BUGS

Please report any bugs or feature requests on the bugtracker website
[https://github.com/metacpan/p5-CatalystX-Fastly-Role-Response/issues](https://github.com/metacpan/p5-CatalystX-Fastly-Role-Response/issues)

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

# AUTHOR

Leo Lapworth

# CONTRIBUTORS

- Graham Knop <haarg@haarg.org>
- Leo Lapworth <leo@cuckoo.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by Leo Lapworth.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
