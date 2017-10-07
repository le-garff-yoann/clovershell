# Copyright (C) 2017-2018 Yoann Le Garff
# clovershell-server is licensed under the Apache License, Version 2.0

package Clovershell::Server::Controller::OpenAPI::Tag;

use Mojo::Base 'Mojolicious::Controller';

sub list {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->pg->db->select('tags', [ qw/name description/ ], sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;

        $c->render(openapi => [ $r->hashes->each ]);
    });
}

sub create {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->pg->db->insert('tags', $c->validation->param('tag'), sub {
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

    $c->pg->db->select('tags', [ '*' ], { name => $c->validation->param('tagName') }, sub {
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

    $c->pg->db->update('tags', $c->validation->param('tag'), { name => $c->validation->param('tagName') }, sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;
        return $c->render(openapi => { error => 'Not found' }, status => 404) unless $r->rows;

        $c->render(openapi => undef);
    });
}

sub delete {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    my $db = $c->pg->db;

    my $tag_name = $c->validation->param('tagName');

    Mojo::IOLoop->delay(
        sub {
            $db->query('
SELECT COUNT(r.*) AS count
FROM clovers_tags r, tags t
WHERE r.tag_id = t.id
AND t.name = ?', $tag_name, shift->begin);
        },
        sub {
            my ($d, $err, $r) = @_;

            die { openapi => { error => $err }, status => 500 } if $err;

            my $attached_clovers_count = $r->hash->{count};

            die { openapi => { error => $attached_clovers_count . ' clovers are attached to this tag' }, status => 409} if $attached_clovers_count;

            $db->delete('tags', { name => $tag_name }, $d->begin);
        },
        sub {
            my ($d, $err, $r) = @_;

            die { openapi => { error => $err }, status => 500 } if $err;
            die { openapi => { error => 'Not found' }, status => 404 } unless $r->rows;

            $c->render(openapi => undef);
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

Clovershell::Server::Controller::OpenAPI::Tag

=head1 COPYRIGHT

Copyright (C) 2017-2018 Yoann Le Garff

=head1 LICENSE

clovershell-server is licensed under the Apache License, Version 2.0

=cut
