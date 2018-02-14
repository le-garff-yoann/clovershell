requires 'FindBin';
requires 'Mojolicious', '>= 7.51', '< 8';
requires 'Mojo::JSON::MaybeXS';
requires 'Mojo::Pg';
requires 'JSON::Validator', '>= 2.03';
requires 'Mojolicious::Plugin::OpenAPI', '>= 1.23';
requires 'Crypt::Eksblowfish::Bcrypt';
requires 'Scalar::Util';
requires 'Scalar::Util::Numeric';

recommends 'EV';
recommends 'Cpanel::JSON::XS';

on test => sub {
    requires 'Test::More';
    requires 'Test::Mojo';
    requires 'OpenAPI::Client', '>= 0.14';
};
