use strict;
use warnings;
use Test::More;

use lib qw(t/lib);

use Catalyst::Test qw( Test::App );

my $no_cache
    = 'no-cache, no-store, must-revalidate, max-age=0, max-stale=0, post-check=0, pre-check=0, private';

subtest 'no special headers' => sub {
    my $res = request('/');
    like $res->content, qr/index page/;

    is $res->header('Surrogate-Control'), undef,
        'No Surrogate-Control header';
    is $res->header('Cache-Control'), undef,
        'No Cache-Control header';
    is $res->header('Pragma'), undef,
        'No Pragma header';
    is $res->header('Expires'), undef,
        'No Expires header';
};

subtest 'XXX_never_cache headers' => sub {
    my $res = request('/page_with_no_caching');
    like $res->content, qr/No caching here/;

    is $res->header('Surrogate-Control'), undef,
        'Surrogate-Control not there as expected';
    is $res->header('Cache-Control'), $no_cache,
        'Cache-Control for no-cache';
    is $res->header('Pragma'),  'no-cache',
        'Pragma: no-cache';
    is $res->header('Expires'), '0',
        'Expires: 0';
};

subtest 'Some caching headers' => sub {
    my $res = request('/some_caching');
    like $res->content, qr/Browser and CDN cacheing different max ages/;

    is $res->header('Surrogate-Control'),
        'max-age=600, stale-while-revalidate=86400, stale-if-error=172800',
        'Surrogate-Control: set to max-age=600, stale-while-revalidate=86400, stale-if-error=172800';
    is $res->header('Cache-Control'),
        'max-age=10, stale-while-revalidate=172800, stale-if-error=259200',
        'Cache-Control for browser set to max-age=10, stale-while-revalidate=172800, stale-if-error=259200';
    is $res->header('Pragma'), undef,
        'No Pragma header';
    is $res->header('Expires'), undef,
        'No Expires header';

};

subtest 'Browser caching, but not CDN' => sub {
    my $res = request('/cdn_no_cache_browser_cache');
    like $res->content, qr/Browser cacheing, CDN no cache/;

    is $res->header('Cache-Control'), 'max-age=10, private',
        'Cache-Control, with private for CDN set to max-age=10, private';
    is $res->header('Surrogate-Control'), undef,
        'No Surrogate-Control header';
    is $res->header('Pragma'), undef,
        'No Pragma header';
    is $res->header('Expires'), undef,
        'No Expires header';
};

subtest 'Browser caching NOT set, and not CDN' => sub {
    my $res = request('/cdn_no_browser_cache_not_set');
    like $res->content, qr/Browser cacheing not set, CDN no cache/;

    is $res->header('Cache-Control'), 'private',
        'Cache-Control, with private for CDN';
    is $res->header('Surrogate-Control'), undef,
        'No Surrogate-Control header';
    is $res->header('Pragma'), undef,
        'No Pragma header';
    is $res->header('Expires'), undef,
        'No Expires header';
};

subtest 'Surrogate keys - basic' => sub {
    my $res = request('/some_surrogate_keys');
    like $res->content, qr/surrogate keys/;

    is $res->header('Surrogate-Key'), 'f%oo W1-BBL3!',
        'Surrogate-Keys: set to "f%oo W1BBL3"';

    is $res->header('Surrogate-Control'), undef,
        'No Surrogate-Control header';
    is $res->header('Cache-Control'), undef,
        'No ache-Control header';
    is $res->header('Pragma'), undef,
        'No Pragma header';
    is $res->header('Expires'), undef,
        'No Expires header';
};

done_testing();
