# Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras
# clovershell is licensed under the Apache License, Version 2.0

package Clovershell::Controller::OpenAPI::Clover;

use Mojo::Base 'Mojolicious::Controller';

use Clovershell::Model::Clovers;

has model => sub {
    state $m = Clovershell::Model::Clovers->new(pg => shift->helpers->pg);
};

sub list {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->list(query => $c->validation->param('query'), tag_query => $c->validation->param('tag_query'), cb => sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;

        $c->render(openapi => [ map { { name => $_->{name}, description => $_->{description}, score => $_->{score} } } $r->hashes->each ]);
    });
}

sub create {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->create(data => $c->validation->param('clover'), cb => sub {
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

    $c->model->read(name => $c->validation->param('cloverName'), cb => sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;

        my $clover = $r->hashes->first or return $c->render(openapi => { error => 'Not found' }, status => 404);

        delete $clover->{id};

        $c->render(openapi => $clover);
    });
}

sub update {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->update(name => $c->validation->param('cloverName'), data => $c->validation->param('clover'), cb => sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;
        return $c->render(openapi => { error => 'Not found' }, status => 404) unless $r->rows;

        $c->render(openapi => undef);
    });
}

sub delete {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->delete(name => $c->validation->param('cloverName'), cb => sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;
        return $c->render(openapi => { error => 'Not found' }, status => 404) unless $r->rows;

        $c->render(openapi => undef);
    });
}

sub list_attached_tags {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->list_attached_tags(query => $c->validation->param('query'), name => $c->validation->param('cloverName'), cb => sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;

        $c->render(openapi => [ map { { name => $_->{name}, description => $_->{description} } } $r->hashes->each ]);
    });
}

sub attach_tag {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->attach_tag(name => $c->validation->param('cloverName'), tag => $c->validation->param('tag'), cb => sub {
        my ($db, $err, $r) = @_;

        if ($err) {
            return $c->render(openapi => { error => 'Already exists' }, status => 409) if $err =~ /already exists/i;
            return $c->render(openapi => { error => 'Clover or tag not found' }, status => 404) if $err =~ /violates not-null constraint/i;

            return $c->render(openapi => { error => $err }, status => 500)
        }

        $c->render(openapi => undef);
    });
}

sub detach_tag {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->detach_tag(name => $c->validation->param('cloverName'), tag => $c->validation->param('tag'), cb => sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;
        return $c->render(openapi => { error => 'Clover or tag not found' }, status => 404) unless $r->rows;

        $c->render(openapi => undef);
    });
}

sub list_plays {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->list_plays(
        name => $c->validation->param('cloverName'),
        query => $c->validation->param('query'),
        cb => sub {
            my ($db, $err, $r) = @_;

            return $c->render(openapi => { error => $err }, status => 500) if $err;

            $c->render(openapi => [ map { { id => $_->{id}, return_code => $_->{return_code}, started_at => $_->{started_at} } } $r->hashes->each ]);
        }
    );
}

sub create_play {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->create_play(
        name => $c->validation->param('cloverName'),
        username => $c->session('username') // $c->req->url->to_abs->username,
        data => $c->validation->param('play')
    )->then(sub {
        $c->render(openapi => { id => shift }, status => 201);
    })->catch(sub {
        my $err = shift;

        if (eval { $err->isa('Clovershell::Exception::OpenAPI') }) {
            $c->render(openapi => { error => $err->message->{error} }, status => $err->message->{status});
        } else {
            $c->render(openapi => { error => $err }, status => 500);
        }
    });
}

sub read_play {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->model->read_play(
        name => $c->validation->param('cloverName'),
        play_id => $c->validation->param('playId'),
        username => $c->session('username') // $c->req->url->to_abs->username,
        cb => sub {
            my ($db, $err, $r) = @_;

            return $c->render(openapi => { error => $err }, status => 500) if $err;

            my $d = $r->hashes->first or return $c->render(openapi => { error => 'Not found' }, status => 404);

            $c->render(openapi => $d);
        }
    );
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Clovershell::Controller::OpenAPI::Clover

=head1 COPYRIGHT

Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras

=head1 LICENSE

clovershell is licensed under the Apache License, Version 2.0

=cut
