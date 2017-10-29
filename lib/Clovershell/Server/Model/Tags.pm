# Copyright (C) 2015-2018 Yoann Le Garff
# clovershell-server is licensed under the Apache License, Version 2.0

package Clovershell::Server::Model::Tags;

use Mojo::Base -base;

use Scalar::Util::Numeric 'isint';

has 'pg';

sub list {
    my ($self, %args) = @_;

    my $q = 'SELECT * FROM tags';

    my @p;

    if (isint($args{limit}) and $args{limit} > 0) {
        $q .= ' LIMIT ?';

        push @p, $args{limit}; 
    }

    $self->pg->db->query($q . ';', @p, $args{cb});
}

sub create {
    my ($self, %args) = @_;

    $self->pg->db->insert('tags', $args{data}, $args{cb});
}

sub read {
    my ($self, %args) = @_;

    $self->pg->db->select('tags', [ '*' ], { name => $args{name} }, $args{cb});
}

sub update {
    my ($self, %args) = @_;

    $self->pg->db->update('tags', $args{data}, { name => $args{name} }, $args{cb});
}

sub delete {
    my ($self, %args) = @_;

    my $delay = Mojo::IOLoop::Delay->new;

    $delay->steps(
        sub {
            $self->count_attached_clovers(name => $args{name}, cb => shift->begin);
        },
        sub {
            my ($d, $err, $r) = @_;

            die { error => $err, status => 500 } if $err;

            my $attached_clovers_count = $r->hash->{counter};

            die { error => $attached_clovers_count . ' clovers are attached to this tag', status => 409 } if $attached_clovers_count;

            $self->pg->db->delete('tags', { name => $args{name} }, $d->begin);
        },
        sub {
            my ($d, $err, $r) = @_;

            die { error => $err, status => 500 } if $err;
            die { error => 'Not found', status => 404 } unless $r->rows;
        }
    );
}

sub count_attached_clovers {
    my ($self, %args) = @_;

    $self->pg->db->query('
SELECT COUNT(r.*) AS counter
FROM clovers_tags r, tags t
WHERE r.tag_id = t.id
AND t.name = ?', $args{name}, $args{cb});
} 

# sub AUTOLOAD {}

# sub DESTROY {}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Clovershell::Server::Model::Tags

=head1 COPYRIGHT

Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras

=head1 LICENSE

clovershell-server is licensed under the Apache License, Version 2.0

=cut
