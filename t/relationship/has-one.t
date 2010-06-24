#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;

use_ok('ObjectDB::Relationship::HasOne');

use lib 't/lib';

use TestDB;

my $rel = ObjectDB::Relationship::HasOne->new(
    class => 'Author',
    name  => 'author_admin'
);
ok($rel);

$rel->build(TestDB->conn);

is($rel->foreign_table, 'author_admins');

is_deeply(
    $rel->to_source,
    {   name       => 'author_admins',
        as         => 'author_admins',
        join       => 'left',
        constraint => ['author_admins.authors_id' => 'authors.id']
    }
);

