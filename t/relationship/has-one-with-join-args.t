#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;

use_ok('ObjectDB::Relationship::HasOne');

use lib 't/lib';

use TestDB;

my $rel = ObjectDB::Relationship::HasOne->new(
    class     => 'Author',
    name      => 'article',
    join_args => [title => 'foo', content => 'bar']
);
ok($rel);

$rel->build(TestDB->conn);

is($rel->foreign_table, 'articles');

is_deeply(
    $rel->to_source,
    {   name       => 'articles',
        as         => 'articles',
        join       => 'left',
        constraint => [
            'articles.authors_id' => 'authors.id',
            'articles.title'     => 'foo',
            'articles.content'   => 'bar'
        ]
    }
);

