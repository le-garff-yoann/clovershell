requires 'FindBin';
requires 'Mojolicious', '== 7.53';
requires 'Mojo::JSON::MaybeXS', '== 1.001';
requires 'Mojo::Pg', '== 4.08';
requires 'JSON::Validator', '== 2.03';
requires 'Mojolicious::Plugin::OpenAPI', '== 1.23';
requires 'Crypt::Eksblowfish::Bcrypt', '== 0.009';
requires 'Scalar::Util';
requires 'Scalar::Util::Numeric';

recommends 'EV';
recommends 'Cpanel::JSON::XS';

on test => sub {
    requires 'Test::More';
    requires 'Test::Mojo';
    requires 'OpenAPI::Client', '== 0.14';
};
