#! perl

use strict;
use warnings;
use Test::More;

use lib qw(lib t/lib);

BEGIN {
	$ENV{CATALYST_DEBUG} = 0;
}

use Test::WWW::Mechanize 1.46; # For the header_xxx tests
use Test::WWW::Mechanize::Catalyst;

my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'Test::App');

$mech->get('/');
$mech->content_contains("index page");

$mech->get('/page_with_no_caching');
$mech->content_contains("No caching here");

$mech->header_is( 'Expires', '0', 'No expires' );
$mech->header_is( 'Surrogate-Control', 'private', 'Surrogate-Control: private' );


done_testing();


