# Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras
# clovershell-server is licensed under the Apache License, Version 2.0

package Clovershell::Server 0.1;

use Mojo::Base 'Mojolicious';

use Mojo::JSON::MaybeXS;
use Mojo::Pg;
use Mojo::URL;

use Scalar::Util::Numeric 'isint';

sub startup {
    my $self = shift;

    $self->app->sessions->cookie_name(__PACKAGE__);

    $self->plugin(Config => {
        default => {
           maximum_users => 0
        }
    });

    $self->log->fatal('maximum_users must be >= 0') unless isint($self->config('maximum_users')) and $self->config('maximum_users') >= 0;
    $self->config('pg') // $self->log->fatal('pg must be defined');

    $self->helper(pg => sub { state $pg = Mojo::Pg->new(shift->config('pg')) });
    $self->helper('clovershell.openapi.url' => sub { state $p = shift->app->home->child('share', 'clovershell.json') });

    $self->plugin(Bcrypt => { cost => 8 });

    $self->pg->migrations->from_file($self->home->child('sql', 'migrations.sql'))->migrate;

    $self->hook(around_action => sub { # https://metacpan.org/pod/Mojolicious::Plugin::OAuth2::Server
        my ($next, $c) = @_;

        return $next->() if $c->session('logged_in');

        my $openapi_spec = $c->openapi->spec;

        return $next->() unless $openapi_spec;
        return $next->() unless $openapi_spec->{'x-clovershell-protected'};

        my $url = $c->req->url->to_abs;

        my $username = $url->username;

        return $c->render(json => undef, status => 401) unless defined $username;

        $c->render_later;

        $c->pg->db->select('users', [ '*' ], { username => $username }, sub {
            my ($db, $err, $r) = @_;

            return $c->render(openapi => { error => $err }, status => 500) if $err;

            my $user = $r->hashes->first;

            return $c->render(json => undef, status => 401) unless $user and $c->bcrypt_validate($url->password, $user->{password});

            $next->();
        });
    });

    $self->hook(before_render => sub {
        my ($c, $args) = @_;

        my $err;

        my $tpl = $args->{template} // '';

        if ($tpl eq 'exception') {
            $err = $c->stash('exception')->message;
        } elsif ($tpl eq 'not_found') {
            $err = "the page you were looking for doesn't exist."
        } else {
            return;
        }

        $args->{json} = { error => $err };
    });

    $self->plugin(OpenAPI => {
        url => $self->clovershell->openapi->url,
        coerce => {}, # empty hashtable is for "coerce nothing"
        renderer => sub {
            my ($c, $d) = @_;

            $d = { error => join "\n", map { $_->{path} . ' - ' . $_->{message} } @{$d->{errors}} } if ref $d eq 'HASH' and ref $d->{errors} eq 'ARRAY';

            Mojolicious::Plugin::OpenAPI::_render_json($c, $d);
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

Clovershell::Server

=head1 COPYRIGHT

Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras

=head1 LICENSE

clovershell-server is licensed under the Apache License, Version 2.0

=cut
