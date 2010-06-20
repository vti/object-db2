#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;

use_ok('ObjectDB::Relationship::BelongsTo');

use lib 't/lib';

use TestDB;

my $rel = ObjectDB::Relationship::BelongsTo->new(
    class     => 'Article',
    name      => 'author',
    join_args => [title => 'foo']
);
ok($rel);

$rel->build(TestDB->dbh);

is($rel->foreign_table, 'authors');

is_deeply(
    $rel->to_source,
    {   name       => 'authors',
        as         => 'authors',
        join       => 'left',
        constraint => [
            'authors.id'    => 'articles.authors_id',
            'authors.title' => 'foo'
        ]
    }
);
