#! perl

use strict;
use warnings;
use Test::More;

use lib qw(lib t/lib);

BEGIN {
    $ENV{CATALYST_DEBUG} = 0;
}

use Test::WWW::Mechanize 1.46;    # For the header_xxx tests
use Test::WWW::Mechanize::Catalyst;

my $no_cache
    = 'no-cache, no-store, must-revalidate, max-age=0, max-stale=0, post-check=0, pre-check=0';

my $mech = Test::WWW::Mechanize::Catalyst->new( catalyst_app => 'Test::App' );

{
    note('Testing no special headers');

    $mech->get('/');
    $mech->content_contains("index page");

    $mech->lacks_header_ok( 'Surrogate-Control',
        'No Surrogate-Control header' );
    $mech->lacks_header_ok( 'Cache-Control', 'No Cache-Control header' );
    $mech->lacks_header_ok( 'Pragma',        'No Pragma header' );
    $mech->lacks_header_ok( 'Expires',       'No Expires header' );
}

{
    note('Testing XXX_never_cache headers');

    $mech->get('/page_with_no_caching');
    $mech->content_contains("No caching here");

    $mech->header_is( 'Surrogate-Control', 'private',
        'Surrogate-Control: private' );
    $mech->header_is( 'Cache-Control', $no_cache,
        'Cache-Control for no-cache' );
    $mech->header_is( 'Pragma',  'no-cache', 'Pragma: no-cache' );
    $mech->header_is( 'Expires', '0',        'Expires: 0' );
}

{
    note('Some caching headers');

    $mech->get('/some_caching');
    $mech->content_contains("Browser and CDN cacheing different max ages");

    $mech->header_is( 'Surrogate-Control', 'max-age=864000',
        'Surrogate-Control: set to max-age=864000' );
    $mech->header_is( 'Cache-Control', 'max-age=86400',
        'Cache-Control for browser set to max-age=86400' );
    $mech->lacks_header_ok( 'Pragma',  'No Pragma header' );
    $mech->lacks_header_ok( 'Expires', 'No Expires header' );

}

done_testing();

