# Copyright (C) 2015-2018 Yoann Le Garff
# clovershell-server is licensed under the Apache License, Version 2.0

package Clovershell::Server::Model::Users;

use Mojo::Base -base;

use Scalar::Util::Numeric 'isint';
use Mojo::IOLoop::Delay;

use Clovershell::Server::Utils qw/bcrypt bcrypt_validate/;

has 'pg';
has bcrypt_cost => undef; 
has maximum_users => 0;

sub list {
    my ($self, %args) = @_;

    my $q = 'SELECT * FROM users';

    my @p;

    if (isint($args{limit}) and $args{limit} > 0) {
        $q .= ' LIMIT ?';

        push @p, $args{limit}; 
    }

    $self->pg->db->query($q . ';', @p, $args{cb});
}

sub count {
    my ($self, %args) = @_;

    $self->pg->db->query('SELECT count(*) AS counter FROM users', $args{cb});
}

sub create {
    my ($self, %args) = @_;

    my $delay = Mojo::IOLoop::Delay->new;

    $delay->steps(
        sub {
            my $d = shift;

            if ($self->maximum_users) {
                $self->count(cb => $d->begin);
            } else {
                $d->pass;
            }
        },
        sub {
            my $d = shift;

            if ($self->maximum_users) {
                my ($err, $r) = @_;

                die { error => $err, status => 500 } if $err;

                die { error => 'Too many users already exists', status => 409 } if $r->hash->{counter} >= $self->maximum_users;
            }

            $self->pg->db->insert('users', { username => $args{data}->{username}, password => bcrypt($args{data}->{password}, $self->bcrypt_cost) }, $d->begin);
        },
        sub {
            my ($d, $err, $r) = @_;

            if ($err) {
                die { error => $err, status => 409 } if $err =~ /already exists/i;

                die { error => $err, status => 500 };
            }
        }
    );
}

sub read {
    my ($self, %args) = @_;

    $self->pg->db->select('users', [ '*' ], { username => $args{name} }, $args{cb});
}

sub check_password {
    my ($self, %args) = @_;

    my $delay = Mojo::IOLoop::Delay->new;

    $delay->steps(
        sub {
            $self->read(name => $args{data}->{username}, cb => shift->begin);
        },
        sub {
            my ($db, $err, $r) = @_;

            die $err if $err;

            my $user = $r->hashes->first;

            shift->begin->(undef, $user && bcrypt_validate($args{data}->{password}, $self->bcrypt_cost, $user->{password}));
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

Clovershell::Server::Model::Users

=head1 COPYRIGHT

Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras

=head1 LICENSE

clovershell-server is licensed under the Apache License, Version 2.0

=cut
