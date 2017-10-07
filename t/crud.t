# Copyright (C) 2017-2018 Yoann Le Garff
# clovershell-server is licensed under the Apache License, Version 2.0

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use OpenAPI::Client;

plan skip_all => 'Assign a PostgreSQL connection string (eg., postgresql://postgres:postgres@localhost/t_clovershell) to $TEST_PG_DSN' unless defined $ENV{TEST_PG_DSN};

package t::Clovershell::OpenAPI::Client {
    sub new {
        my $class = shift;

        my %o = ( t => Test::Mojo->new(@_) );

        $o{o} = OpenAPI::Client->new($o{t}->app->clovershell->openapi->url, { # couldn't use a url: the ua used in the constructor block the event loop that is running the test server ...
            app => $o{t}->ua->server->app
        });

        bless \%o, $class;
    }

    sub op {
        my ($self, $op, @args) = @_;

        my $tx; $self->{o}->$op(@args, sub {
            $tx = $_[1];
        });

        $self->{t}->ua->server->ioloop->one_tick until $tx;

        $tx;
    }

    sub t_op {
        my $self = shift;

        $self->{t}->tx($self->op(@_));
    }
};

my $c = t::Clovershell::OpenAPI::Client->new('Clovershell::Server' => {
    maximum_users => 2,
    pg => $ENV{TEST_PG_DSN},
    secrets => [ 's3cret' ]
});

$c->t_op('listClovers')->status_is(200)->json_is([]);
$c->t_op('createClover', { clover => { name => 'c', description => '', template => 'echo 0' }})->status_is(201);
$c->t_op('createClover', { clover => { name => 'c', description => '', template => 'echo 0' }})->status_is(409);
$c->t_op('listClovers')->status_is(200)->json_is([{ name => 'c', description => '', score => 0 }]);
$c->t_op('readClover', { cloverName => 'c' })->status_is(200)->json_is({ name => 'c', description => '', template => 'echo 0', score => 0 });
$c->t_op('updateClover', { cloverName => 'c', clover => { description => 'PUT' }})->status_is(200);
$c->t_op('readClover', { cloverName => 'c' })->status_is(200)->json_is({ name => 'c', description => 'PUT', template => 'echo 0', score => 0 });
$c->t_op('readClover', { cloverName => 't' })->status_is(404);

$c->t_op('listTags')->status_is(200)->json_is([]);
$c->t_op('createTag', { tag => { name => 't', description => '' }})->status_is(201);
$c->t_op('createTag', { tag => { name => 't', description => '' }})->status_is(409);
$c->t_op('createTag', { tag => { name => 'tt', description => '' }})->status_is(201);
$c->t_op('listTags')->status_is(200)->json_is([{ name => 't', description => '' }, { name => 'tt', description => '' }]);
$c->t_op('readTag', { tagName => 't' })->status_is(200)->json_is({ name => 't', description => '' });
$c->t_op('updateTag', { tagName => 't', tag => { description => 'PUT' }})->status_is(200);
$c->t_op('readTag', { tagName => 't' })->status_is(200)->json_is({ name => 't', description => 'PUT' });
$c->t_op('readTag', { tagName => 'c' })->status_is(404);

$c->t_op('listTagsAttachToClover', { cloverName => 'c' })->status_is(200)->json_is([]);
$c->t_op('attachCloverToTag', { cloverName => 'c', tag => 't' })->status_is(200);
$c->t_op('attachCloverToTag', { cloverName => 'c', tag => 'tt' })->status_is(200);
$c->t_op('attachCloverToTag', { cloverName => 'c', tag => 'c' })->status_is(404);
$c->t_op('listTagsAttachToClover', { cloverName => 'c' })->status_is(200)->json_is([{ name => 't', description => 'PUT' }, { name => 'tt', description => '' }]);
$c->t_op('listClovers', { tag => [ 't', 'tt' ]})->status_is(200)->json_is([{ name => 'c', description => 'PUT', score => 0 }]);

$c->t_op('deleteTag', { tagName => 't' })->status_is(409);

$c->t_op('detachCloverFromTag', { cloverName => 'c', tag => 't' })->status_is(200);
$c->t_op('detachCloverFromTag', { cloverName => 'c', tag => 'tt' })->status_is(200);
$c->t_op('detachCloverFromTag', { cloverName => 'c', tag => 'c' })->status_is(404);
$c->t_op('listTagsAttachToClover', { cloverName => 'c' })->status_is(200)->json_is([]);
$c->t_op('listClovers', { tag => [ 't' ]})->status_is(200)->json_is([]);

$c->t_op('listPlaysForClover', { cloverName => 'c' })->status_is(200)->json_is([]);
$c->t_op('createPlayForClover', { cloverName => 'c', play => { return_code => 0, started_at => '2017-01-01 00:00:00', stdout => '', stderr => '' }})->status_is(401);

$c->t_op('registerUser', { userinfo => { username => 'u', password => 'p' }})->status_is(201);
$c->t_op('registerUser', { userinfo => { username => 'u', password => 'p' }})->status_is(409);
$c->t_op('registerUser', { userinfo => { username => 'uu', password => 'p' }})->status_is(201);
$c->t_op('registerUser', { userinfo => { username => 'uuu', password => 'p' }})->status_is(409);
$c->t_op('loginUser', { userinfo => { username => 'u', password => 'p' }})->status_is(201);

$c->t_op('createPlayForClover', { cloverName => 'c', play => { return_code => 0, started_at => '2017-01-01 00:00:00', stdout => '&1', stderr => '&2' }})->status_is(201);
$c->t_op('listPlaysForClover', { cloverName => 'c', started_after => '2016-12-31 23:00:00' })->status_is(200)->json_like('/0/id', qr/^\d+$/)->json_is('/0/started_at' => '2017-01-01 00:00:00')->json_is('/0/return_code' => 0);
$c->t_op('listPlaysForClover', { cloverName => 'c', started_after => '2017-01-01 00:00:01' })->status_is(200)->json_is([]);
$c->t_op('listPlaysForClover', { cloverName => 'c', return_code => [ 1 ] })->status_is(200)->json_is([]);

my $clover_id = $c->op('listPlaysForClover', { cloverName => 'c' })->result->json('/0/id');

$c->t_op('readPlayForClover', { cloverName => 'c', playId => $clover_id })->status_is(200)->json_is({ id => $clover_id, return_code => 0, started_at => '2017-01-01 00:00:00', stdout => '&1', stderr => '&2' });

$c->t_op('logoutUser')->status_is(200);

$c->t_op('readPlayForClover', { cloverName => 'c', playId => $clover_id })->status_is(200)->json_is({ id => $clover_id, return_code => 0, started_at => '2017-01-01 00:00:00' });
$c->t_op('readClover', { cloverName => 'c' })->status_is(200)->json_unlike('/score', qr/^0$/);

$c->t_op('deleteTag', { tagName => 't' })->status_is(200);
$c->t_op('deleteTag', { tagName => 'tt' })->status_is(200);
$c->t_op('listTags')->status_is(200)->json_is([]);
$c->t_op('deleteClover', { cloverName => 'c' })->status_is(200);
$c->t_op('listClovers')->status_is(200)->json_is([]);

done_testing();

END {
    $c->{t}->app->pg->db->delete('users') if $c;
}

__END__
