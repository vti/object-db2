#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;

use_ok('ObjectDB::Relationship::BelongsTo');

use lib 't/lib';

use TestDB;
use TestEnv;
TestEnv->setup;

my $rel = ObjectDB::Relationship::BelongsTo->new(
    class     => 'Article',
    name      => 'author',
    join_args => [title => \'foo']
);
ok($rel);

is($rel->type, 'belongs_to');
ok($rel->is_belongs_to);

$rel->build(TestDB->dbh);

is($rel->foreign_table, 'authors');

is_deeply(
    $rel->to_source,
    {   name       => 'authors',
        as         => 'author',
        join       => 'left',
        constraint => [
            'author.id'    => \'`articles`.`author_id`',
            'author.title' => \'foo'
        ]
    }
);
