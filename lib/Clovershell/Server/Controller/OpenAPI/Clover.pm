# Copyright (C) 2017-2018 Yoann Le Garff
# clovershell-server is licensed under the Apache License, Version 2.0

package Clovershell::Server::Controller::OpenAPI::Clover;

use Mojo::Base 'Mojolicious::Controller';

use Scalar::Util 'blessed';

sub list {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    my $q = '
SELECT c.name, c.description, c.score
FROM clovers c';

    my @p;

    if (my @tags = @{$c->validation->output->{'tag'}}) {
        my $t_filter = ' c.id IN (SELECT clover_id FROM clovers_tags r, tags t WHERE r.tag_id = t.id AND t.name = ?) ';

        $q .= 'WHERE' . $t_filter;

        push @p, shift @tags;

        $q .= 'AND' . $t_filter for @tags;

        push @p, @tags;
    }

    $c->pg->db->query($q . ' ORDER BY c.score ASC;', @p, sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;

        $c->render(openapi => [ $r->hashes->each ]);
    });
}

sub create {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->pg->db->insert('clovers', $c->validation->param('clover'), sub {
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

    $c->pg->db->select('clovers', [ '*' ], { name => $c->validation->param('cloverName') }, sub {
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

    $c->pg->db->update('clovers', $c->validation->param('clover'), { name => $c->validation->param('cloverName') }, sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;
        return $c->render(openapi => { error => 'Not found' }, status => 404) unless $r->rows;

        $c->render(openapi => undef);
    });
}

sub delete {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->pg->db->delete('clovers', { name => $c->validation->param('cloverName') }, sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;
        return $c->render(openapi => { error => 'Not found' }, status => 404) unless $r->rows;

        $c->render(openapi => undef);
    });
}

sub list_attached_tags {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->pg->db->query('
SELECT t.name, t.description
FROM clovers c, tags t, clovers_tags r
WHERE c.id = r.clover_id
AND r.tag_id = t.id
AND c.name = ?;', $c->validation->param('cloverName'), sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;

        $c->render(openapi => [ $r->hashes->each ]);
    });
}

sub attach_tag {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    $c->pg->db->query('
INSERT INTO clovers_tags
VALUES ((SELECT id FROM clovers WHERE name = ?), (SELECT id FROM tags WHERE name = ?));', $c->validation->param('cloverName'), $c->validation->param('tag'), sub {
        my ($db, $err, $r) = @_;

        if ($err) { # TODO: need tests
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

    $c->pg->db->query('
DELETE FROM clovers_tags
WHERE clover_id = (
    SELECT id FROM clovers WHERE name = ?
)
AND tag_id = (
    SELECT id FROM tags WHERE name = ?
);', $c->validation->param('cloverName'), $c->validation->param('tag'), sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;
        return $c->render(openapi => { error => 'Clover or tag not found' }, status => 404) unless $r->rows;

        $c->render(openapi => undef);
    });
}

sub list_plays {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    my $q = '
SELECT p.id, p.started_at, p.return_code
FROM plays p, clovers c
WHERE p.clover_id = c.id
AND c.name = ?';

    my @p = ($c->validation->param('cloverName'));

    if (defined (my $started_after = $c->validation->param('started_after'))) {
        push @p, $started_after;

        $q .= ' AND p.started_at::TIMESTAMP >= ?';
    }

    if (my @return_codes = @{$c->validation->output->{'return_code'}}) {
        push @p, @return_codes;

        $q .= ' AND p.return_code IN (' . join(',', ('?') x @return_codes) . ')';
    }

    $c->pg->db->query($q . ' ORDER BY p.started_at ASC;', @p, sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;

        $c->render(openapi => [ $r->hashes->each ]);
    });
}

sub create_play {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    my $username = $c->session('username') // $c->req->url->to_abs->username;

    my $db = $c->pg->db;

    my $tx = $db->begin;

    Mojo::IOLoop->delay(
        sub {
            $c->pg->db->select('clovers', [ 'id' ], { name => $c->validation->param('cloverName') }, shift->begin);
        },
        sub {
            my ($d, $err, $r) = @_;

            die { openapi => { error => $err }, status => 500 } if $err;

            my $clover_id = $r->hash->{id} // die { openapi => { error => 'Clover not found' }, status => 404 };

            $c->pg->db->select('users', [ 'id' ], { username => $username }, $d->begin);

            $db->insert('plays', {
                %{$c->validation->param('play')},
                %{{
                    clover_id => $clover_id
                }}
            }, { returning => 'id' }, $d->begin);
        },
        sub {
            my ($d, $err1, $r1, $err2, $r2) = @_;

            die { openapi => { error => $err1 }, status => 500 } if $err1;
            die { openapi => { error => $err2 }, status => 500 } if $err2;

            my $user_id = $r1->hash->{id} // die { openapi => { error => 'User not found' }, status => 404 };

            $d->data(play_id => $r2->hash->{id});

            $db->insert('plays_users', { 'play_id' => $d->data('play_id'), 'user_id' => $user_id }, $d->begin);
        }, sub {
            my ($d, $err, $r) = @_;

            die { openapi => { error => $err }, status => 500 } if $err;

            $tx->commit;

            $c->render(openapi => { id => $d->data('play_id') }, status => 201);
        }
    )->catch(sub {
        my ($d, $err) = @_;

        if (ref $err eq 'HASH' and exists $err->{openapi}) {
            $c->render(%{$err});
        } else {
            $c->render(openapi => { error => $err }, status => 500);
        }
    });
}

sub read_play {
    my $c = shift->openapi->valid_input or return;

    $c->render_later;

    my $q = 'SELECT p.id, p.started_at, p.return_code';
    my @p = ($c->validation->param('playId'), $c->validation->param('cloverName'));

    if (defined (my $username = $c->session('username') // $c->req->url->to_abs->username)) {
        $q .= ', p.stdout, p.stderr FROM plays p, clovers c, users u, plays_users r
WHERE p.id = ?
AND p.clover_id = c.id
AND c.name = ?
AND p.id = r.play_id
AND r.user_id = u.id
AND u.username = ?;';

        push @p, $username;
    } else {
        $q .= ' FROM plays p, clovers c
WHERE p.id = ?
AND p.clover_id = c.id
AND c.name = ?;';
    }

    $c->pg->db->query($q, @p, sub {
        my ($db, $err, $r) = @_;

        return $c->render(openapi => { error => $err }, status => 500) if $err;

        my $d = $r->hashes->first or return $c->render(openapi => { error => 'Not found' }, status => 404);

        $c->render(openapi => $d);
    });
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Clovershell::Server::Controller::OpenAPI::Clover

=head1 COPYRIGHT

Copyright (C) 2017-2018 Yoann Le Garff

=head1 LICENSE

clovershell-server is licensed under the Apache License, Version 2.0

=cut
