# Copyright (C) 2015-2018 Yoann Le Garff
# clovershell-server is licensed under the Apache License, Version 2.0

package Clovershell::Server::Controller::OpenAPI::User;

use Mojo::Base 'Mojolicious::Controller';

use Clovershell::Server::Model::Users;

has model => sub {
    my $c = shift;

    state $m = Clovershell::Server::Model::Users->new(
        pg => $c->helpers->pg,
        bcrypt_cost => $c->helpers->clovershell->bcrypt->cost,
        maximum_users => $c->helpers->config('maximum_users')
    );
};

sub login {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    my $userinfo = $c->validation->param('userinfo');

    $c->model->check_password(data => $userinfo)->then(sub {
        my $r = shift;

        return $c->session(logged_in => 1)->session(username => $userinfo->{username})->render(openapi => undef, status => 201) if $r;

        $c->render(openapi => undef, status => 401);
    })->catch(sub {
        $c->render(openapi => { error => shift }, status => 500);
    });
}

sub logout {
    my $c = shift->openapi->valid_input or return;

    return $c->session(expires => 1)->render(openapi => undef, status => 200) if $c->session('logged_in');

    $c->render(openapi => undef, status => 400);
}

sub register {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->create(data => $c->validation->param('userinfo'))->then(sub {
        $c->render(openapi => undef, status => 201);
    })->catch(sub {
        my $err = shift;

        if (eval { $err->isa('Clovershell::Server::Exception::OpenAPI') }) {
            $c->render(openapi => { error => $err->message->{error} }, status => $err->message->{status});
        } else {
            $c->render(openapi => { error => $err }, status => 500);
        }
    });
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Clovershell::Server::Controller::OpenAPI::User

=head1 COPYRIGHT

Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras

=head1 LICENSE

clovershell-server is licensed under the Apache License, Version 2.0

=cut
