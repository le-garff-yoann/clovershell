# Copyright (C) 2015-2018 Yoann Le Garff
# clovershell-server is licensed under the Apache License, Version 2.0

package Clovershell::Server::Model::Clovers;

use Mojo::Base -base;

use Scalar::Util::Numeric 'isint';
use Mojo::IOLoop::Delay;

use Clovershell::Server::Model::Users;

has 'pg';

sub list {
    my ($self, %args) = @_;

    my $q = '
SELECT *
FROM clovers';

    my @p;

    if (ref $args{tags} eq 'ARRAY' and my @tags = @{$args{tags}}) {
        my $filter = ' id IN (SELECT r.clover_id FROM clovers_tags r, tags t WHERE r.tag_id = t.id AND t.name = ?)';

        $q .= ' WHERE' . $filter;

        push @p, shift @tags;

        $q .= ' AND' . $filter for @tags;

        push @p, @tags;
    }

    if (isint($args{limit}) and $args{limit} > 0) {
        $q .= ' LIMIT ?';

        push @p, $args{limit}; 
    }

    $self->pg->db->query($q . ' ORDER BY score ASC;', @p, $args{cb});
}

sub create {
    my ($self, %args) = @_;

    $self->pg->db->insert('clovers', $args{data}, $args{cb});
}

sub read {
    my ($self, %args) = @_;

    $self->pg->db->select('clovers', [ '*' ], { name => $args{name} }, $args{cb});
}

sub update {
    my ($self, %args) = @_;

    $self->pg->db->update('clovers', $args{data}, { name => $args{name} }, $args{cb});
}

sub delete {
    my ($self, %args) = @_;

    $self->pg->db->delete('clovers', { name => $args{name} }, $args{cb});
}

sub list_attached_tags {
    my ($self, %args) = @_;

    $self->pg->db->query('
SELECT t.name, t.description
FROM clovers c, tags t, clovers_tags r
WHERE c.id = r.clover_id
AND r.tag_id = t.id
AND c.name = ?;', $args{name}, $args{cb});
}

sub attach_tag {
    my ($self, %args) = @_;

    $self->pg->db->query('
INSERT INTO clovers_tags
VALUES ((SELECT id FROM clovers WHERE name = ?), (SELECT id FROM tags WHERE name = ?));', $args{name}, $args{tag}, $args{cb});
}

sub detach_tag {
    my ($self, %args) = @_;

    $self->pg->db->query('
DELETE FROM clovers_tags
WHERE clover_id = (
    SELECT id FROM clovers WHERE name = ?
)
AND tag_id = (
    SELECT id FROM tags WHERE name = ?
);', $args{name}, $args{tag}, $args{cb});
}

sub list_plays {
    my ($self, %args) = @_;

    my $q = '
SELECT p.id, p.started_at, p.return_code
FROM plays p, clovers c
WHERE p.clover_id = c.id
AND c.name = ?';

    my @p = ($args{name});

    if (defined $args{started_after}) {
        push @p, $args{started_after};

        $q .= ' AND p.started_at::TIMESTAMP >= ?';
    }

    if (ref $args{return_codes} eq 'ARRAY' and my @return_codes = @{$args{return_codes}}) {
        push @p, @return_codes;

        $q .= ' AND p.return_code IN (' . join(',', ('?') x @return_codes) . ')';
    }

    $self->pg->db->query($q . ' ORDER BY p.started_at ASC;', @p, $args{cb});
}

sub create_play {
    my ($self, %args) = @_;

    my $db = $self->pg->db;

    my $tx = $db->begin;

    my $delay = Mojo::IOLoop::Delay->new;

    $delay->steps(
        sub {
            $self->read(name => $args{name}, cb => shift->begin);
        },
        sub {
            my ($d, $err, $r) = @_;

            die { error => $err, status => 500 } if $err;

            my $clover = $r->hashes->first or die { error => 'Clover not found', status => 404 };

            state $user_model = Clovershell::Server::Model::Users->new(pg => $self->pg);

            $user_model->read(name => $args{username}, cb => $d->begin);

            $db->insert('plays', {
                %{$args{data}},
                %{{
                    clover_id => $clover->{id}
                }}
            }, { returning => 'id' }, $d->begin);
        },
        sub {
            my ($d, $err1, $r1, $err2, $r2) = @_;

            die { error => $err1, status => 500 } if $err1;
            die { error => $err2, status => 500 } if $err2;

            my $user = $r1->hashes->first or die { error => 'User not found', status => 404 };

            $d->data(play_id => $r2->hash->{id});

            $db->insert('plays_users', { 'play_id' => $d->data('play_id'), 'user_id' => $user->{id} }, $d->begin);
        }, sub {
            my ($d, $err, $r) = @_;

            die { error => $err, status => 500 } if $err;

            $tx->commit;

            $d->begin->(undef, $d->data('play_id'));
        }
    );
}

sub read_play {
    my ($self, %args) = @_;

    my $q = 'SELECT p.id, p.started_at, p.return_code';
    my @p = ($args{play_id}, $args{name});

    if (defined $args{username}) {
        $q .= ', p.stdout, p.stderr FROM plays p, clovers c, users u, plays_users r
WHERE p.id = ?
AND p.clover_id = c.id
AND c.name = ?
AND p.id = r.play_id
AND r.user_id = u.id
AND u.username = ?;';

        push @p, $args{username};
    } else {
        $q .= ' FROM plays p, clovers c
WHERE p.id = ?
AND p.clover_id = c.id
AND c.name = ?;';
    }

    $self->pg->db->query($q, @p, $args{cb});
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Clovershell::Server::Model::Clovers

=head1 COPYRIGHT

Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras

=head1 LICENSE

clovershell-server is licensed under the Apache License, Version 2.0

=cut