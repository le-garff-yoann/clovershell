# Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras
# clovershell-server is licensed under the Apache License, Version 2.0

use Mojo::Base -strict;

use Test::More;

BEGIN {
    use_ok('Clovershell::Server::Exception::OpenAPI');
}

my $e = Clovershell::Server::Exception::OpenAPI->new({ error => 'err', status => 500 });

ok(eval { $e->isa('Mojo::Exception') }, "e->isa('Mojo::Exception')");

done_testing();

__END__
