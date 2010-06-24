#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;

use_ok('ObjectDB::Relationship::BelongsToOne');

use lib 't/lib';

use TestDB;

my $rel = ObjectDB::Relationship::BelongsToOne->new(
    class => 'AuthorAdmin',
    name  => 'author'
);
ok($rel);

$rel->build(TestDB->conn);

is($rel->foreign_table, 'authors');

is_deeply(
    $rel->to_source,
    {   name       => 'authors',
        as         => 'authors',
        join       => 'left',
        constraint => ['authors.id' => 'author_admins.authors_id']
    }
);

