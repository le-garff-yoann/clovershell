# Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras
# clovershell-server is licensed under the Apache License, Version 2.0

package Clovershell::Server::Controller::OpenAPI::Tag;

use Mojo::Base 'Mojolicious::Controller';

use Clovershell::Server::Model::Tags;

has model => sub {
    state $m = Clovershell::Server::Model::Tags->new(pg => shift->helpers->pg);
};

sub list {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->list(cb => sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;

        $c->render(openapi => [ map { { name => $_->{name}, description => $_->{description} } } $r->hashes->each ]);
    });
}

sub create {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->create(data => $c->validation->param('tag'), cb => sub {
        my ($db, $err, $r) = @_;

        if ($err) {
            return $c->render(openapi => { error => 'Already exists' }, status => 409) if $err =~ /already exists/i;

            return $c->render(openapi => { error => $err }, status => 500);
        }
        
        $c->render(openapi => undef, status => 201);
    });
}

sub read {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->read(name => $c->validation->param('tagName'), cb => sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;

        my $tag = $r->hashes->first or return $c->render(openapi => { error => 'Not found' }, status => 404);

        delete $tag->{id};

        $c->render(openapi => $tag);
    });
}

sub update {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->update(name => $c->validation->param('tagName'), data => $c->validation->param('tag'), cb => sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;
        return $c->render(openapi => { error => 'Not found' }, status => 404) unless $r->rows;

        $c->render(openapi => undef);
    });
}

sub delete {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->delete(name => $c->validation->param('tagName'))->then(sub {
        $c->render(openapi => undef);
    })->catch(sub {
        my $err = shift;

        if (ref $err eq 'HASH' and exists $err->{error} and exists $err->{status}) {
            $c->render(openapi => { error => $err->{error} }, status => $err->{status});
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

Clovershell::Server::Controller::OpenAPI::Tag

=head1 COPYRIGHT

Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras

=head1 LICENSE

clovershell-server is licensed under the Apache License, Version 2.0

=cut
