use Mojo::Base -strict;

use Test::More;

BEGIN {
    use_ok('Clovershell::Exception::OpenAPI');
}

my $e = Clovershell::Exception::OpenAPI->new({ error => 'err', status => 500 });

ok(eval { $e->isa('Mojo::Exception') }, "e->isa('Mojo::Exception')");

done_testing();
