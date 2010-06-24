#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;

use ObjectDB::Relationship::HasMany;

use lib 't/lib';

use TestDB;

my $rel = ObjectDB::Relationship::HasMany->new(
    class => 'Author',
    name  => 'articles',
    where => [type => 'article'],
);
ok($rel);

$rel->build(TestDB->conn);

is($rel->foreign_table, 'articles');

is_deeply(
    $rel->to_source,
    {   name => 'articles',
        as   => 'articles',
        join => 'left',
        constraint =>
          ['articles.authors_id' => 'authors.id', 'articles.type' => 'article']
    }
);

