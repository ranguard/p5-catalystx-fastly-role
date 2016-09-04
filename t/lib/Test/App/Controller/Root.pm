package Test::App::Controller::Root;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config( namespace => '' );

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    # Hello World
    $c->response->body('index page');
}

sub default : Path {
    my ( $self, $c ) = @_;
    $c->response->body('Page not found');
    $c->response->status(404);
}

sub page_with_no_caching : Path('page_with_no_caching') {
    my ( $self, $c ) = @_;

    # Should have no effect as we are setting never_cache
    $c->cdn_max_age('1d');
    $c->browser_max_age('1w');

    $c->browser_never_cache(1);
    $c->cdn_never_cache(1);

    $c->response->body('No caching here');
}

sub some_caching : Path('some_caching') {
    my ( $self, $c ) = @_;

    $c->cdn_max_age('10m');
    $c->cdn_stale_if_error('2d');
    $c->cdn_stale_while_revalidate('1d');

    $c->browser_max_age('10s');
    $c->browser_stale_if_error('3d');
    $c->browser_stale_while_revalidate('2d');

    $c->response->body('Browser and CDN cacheing different max ages');
}

sub some_keys : Path('some_surrogate_keys') {
    my ( $self, $c ) = @_;

    $c->add_surrogate_key( 'f%oo', 'W1BBL3!' );

    $c->response->body('surrogate keys');
}

sub some_keys_standardized : Path('some_surrogate_keys_standardized') {
    my ( $self, $c ) = @_;

    $c->cdn_standardize_surrogate_keys(1);

    $c->add_surrogate_key( 'f%oo', 'W1BBL3!' );

    $c->purge_surrogate_key('B%aR');

    $c->response->body('surrogate keys standardized');
}

sub end : ActionClass('RenderView') { }

__PACKAGE__->meta->make_immutable;

1;
