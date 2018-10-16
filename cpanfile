requires 'FindBin';
requires 'Mojolicious', '== 8.02';
requires 'Mojo::Pg', '== 4.10';
requires 'JSON::Validator', '== 2.12';
requires 'Mojolicious::Plugin::OpenAPI', '== 1.30';
requires 'Crypt::Eksblowfish::Bcrypt', '== 0.009';
requires 'Scalar::Util';
requires 'Scalar::Util::Numeric';

recommends 'EV';
recommends 'Cpanel::JSON::XS';

on test => sub {
    requires 'Test::More';
    requires 'Test::Mojo';
    requires 'OpenAPI::Client', '== 0.20';
};
