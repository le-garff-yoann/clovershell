# Copyright (C) 2017-2018 Yoann Le Garff, Boquet Nicolas and Yann Le Bras
# clovershell-server is licensed under the Apache License, Version 2.0

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'Clovershell::Server',
    VERSION_FROM => 'lib/Clovershell/Server.pm',
    ABSTRACT => 'clovershell-server',
    AUTHOR => 'Yoann Le Garff',
    LICENSE => 'Apache License, Version 2.0',
    META_MERGE => {
        resources => {
            license => 'http://www.apache.org/licenses/LICENSE-2.0.html',
            repository => 'http://github.com/le-garff-yoann/clovershell-server'
        }
    },
    PREREQ_PM => {
        'FindBin' => 0,
        'EV' => 0,
        'Mojolicious' => 0,
        # 'Mojolicious::Plugin::Model' => 0,
        'Mojo::JSON::MaybeXS' => 0,
        'Mojo::Pg' => 0,
        'Mojolicious::Plugin::Bcrypt' => 0,
        'JSON::Validator' => 1.04,
        'Mojolicious::Plugin::OpenAPI' => 1.15,
        'Scalar::Util' => 0,
        'Scalar::Util::Numeric' => 0
    },
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 6.64
    },
    TEST_REQUIRES => {
        'Test::More' => 0,
        'Test::Mojo' => 0,
        'OpenAPI::Client' => 0
    }
);

__END__
