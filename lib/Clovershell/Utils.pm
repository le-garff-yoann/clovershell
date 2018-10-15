# Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras
# clovershell is licensed under the Apache License, Version 2.0

package Clovershell::Utils;

use Mojo::Base -strict;

use Exporter 'import';
use Crypt::Eksblowfish::Bcrypt qw/en_base64/;

our @EXPORT_OK = qw/bcrypt bcrypt_validate/;

# _salt, bcrypt and bcrypt_validate come originally from Mojolicious::Plugin::Bcrypt@0.14

sub _salt { 
    my $num = 999999;

    my $cr = crypt(rand($num), rand($num)) . crypt(rand($num), rand($num));

    en_base64(substr $cr, 4, 16);
}

sub bcrypt {
    my ($password, $cost, $settings) = @_;

    unless (defined $settings and $settings =~ /^\$2a\$/) {
        $cost = sprintf '%02d', $cost || 6;

        $settings = join '$', '$2a', $cost, _salt;
    }

    return Crypt::Eksblowfish::Bcrypt::bcrypt($password, $settings);
}

sub bcrypt_validate {
    my ($plain, $cost, $crypted) = @_;

    return bcrypt($plain, $cost, $crypted) eq $crypted;
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Clovershell::Utils

=head1 COPYRIGHT

Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras

=head1 LICENSE

clovershell is licensed under the Apache License, Version 2.0

=cut
