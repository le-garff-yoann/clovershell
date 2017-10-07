# Copyright (C) 2015-2018 Yoann Le Garff
# clovershell-server is licensed under the Apache License, Version 2.0

package Clovershell::Server::Controller::OpenAPI::User;

use Mojo::Base 'Mojolicious::Controller';

sub login {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    my $userinfo = $c->validation->param('userinfo');

    $c->pg->db->select('users', [ '*' ], { username => $userinfo->{username} }, sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;

        my $user = $r->hashes->first;

        return $c->session(logged_in => 1)->session(username => $userinfo->{username})->render(openapi => undef, status => 201) if $user and $c->bcrypt_validate($userinfo->{password}, $user->{password});

        $c->render(openapi => undef, status => 401);
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

    my $maximum_users = $c->app->config('maximum_users');

    my $db = $c->pg->db;

    Mojo::IOLoop->delay(
        sub {
            my $d = shift;

            if ($maximum_users) {
                $db->query('SELECT count(*) AS count FROM users', $d->begin);
            } else {
                $d->pass;
            }
        },
        sub {
            my $d = shift;

            if ($maximum_users) {
                my ($err, $r) = @_;

                die { openapi => { error => $err }, status => 500 } if $err;

                die { openapi => { error => 'Too many users already exists' }, status => 409 } if $r->hash->{count} >= $maximum_users;
            }

            my $userinfo = $c->validation->param('userinfo');

            $db->insert('users', { username => $userinfo->{username}, password => $c->bcrypt($userinfo->{password}) }, $d->begin);
        },
        sub {
            my ($d, $err, $r) = @_;

            if ($err) {
                die { openapi => { error => $err }, status => 409 } if $err =~ /already exists/i;

                die { openapi => { error => $err }, status => 500 };
            }

            $c->render(openapi => undef, status => 201);
        }
    )->catch(sub {
        my ($d, $err) = @_;

        if (ref $err eq 'HASH' and exists $err->{openapi}) {
            $c->render(%{$err});
        } else {
            $c->render({ openapi => { error => $err }, status => 500 });
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

Copyright (C) 2017-2018 Yoann Le Garff

=head1 LICENSE

clovershell-server is licensed under the Apache License, Version 2.0

=cut
