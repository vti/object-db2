#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;

use_ok('ObjectDB::Relationship::BelongsTo');

use lib 't/lib';

use TestDB;

my $rel = ObjectDB::Relationship::BelongsTo->new(
    class     => 'Article',
    name      => 'author',
    join_args => [title => \'foo']
);
ok($rel);

is($rel->type, 'belongs_to');
ok($rel->is_belongs_to);

$rel->build(TestDB->conn);

is($rel->foreign_table, 'authors');

is_deeply(
    $rel->to_source,
    {   name       => 'authors',
        as         => 'authors',
        join       => 'left',
        constraint => [
            'authors.id'    => \'`articles`.`author_id`',
            'authors.title' => \'foo'
        ]
    }
);
