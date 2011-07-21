#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;

use_ok('ObjectDB::Relationship::HasOne');

use lib 't/lib';

use TestDB;
use TestEnv;
TestEnv->setup;

my $rel = ObjectDB::Relationship::HasOne->new(
    class => 'Author',
    name  => 'author_admin'
);
ok($rel);

is($rel->type, 'has_one');
ok($rel->is_has_one);

$rel->build(TestDB->init_conn);

is($rel->foreign_table, 'author_admins');

is_deeply(
    $rel->to_source,
    {   name       => 'author_admins',
        as         => 'author_admins',
        join       => 'left',
        constraint => ['author_admins.author_id' => \'`authors`.`id`']
    }
);

