# Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras
# clovershell is licensed under the Apache License, Version 2.0

use Mojo::Base -strict;

use Test::More;

BEGIN {
    use_ok('Clovershell::Utils');
}

# This come originally from Mojolicious::Plugin::Bcrypt@0.14

my $password = 's3cr3t';
my $cost = 6;

my $bcrypted = Clovershell::Utils::bcrypt($password, $cost);

ok(Clovershell::Utils::bcrypt_validate($password, $cost, $bcrypted), 'accept');
ok( ! Clovershell::Utils::bcrypt_validate('secret', $cost, $bcrypted), 'deny');

done_testing();

__END__
