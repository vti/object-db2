#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;

use_ok('ObjectDB::Relationship::BelongsToOne');

use lib 't/lib';

use TestDB;
use TestEnv;
TestEnv->setup;

my $rel = ObjectDB::Relationship::BelongsToOne->new(
    class => 'AuthorAdmin',
    name  => 'author'
);
ok($rel);

is($rel->type, 'belongs_to_one');
ok($rel->is_belongs_to_one);

$rel->build(TestDB->dbh);

is($rel->foreign_table, 'authors');

is_deeply(
    $rel->to_source,
    {   name       => 'authors',
        as         => 'authors',
        join       => 'left',
        constraint => ['authors.id' => \'`author_admins`.`author_id`']
    }
);

