#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 5;

use ObjectDB::Relationship::HasMany;

use lib 't/lib';

use TestDB;
use TestEnv;
TestEnv->setup;

my $rel = ObjectDB::Relationship::HasMany->new(
    class => 'Author',
    name  => 'articles',
    where => [type => \'article'],
);
ok($rel);

is($rel->type, 'has_many');
ok($rel->is_has_many);

$rel->build(TestDB->init_conn);

is($rel->foreign_table, 'articles');

is_deeply(
    $rel->to_source,
    {   name       => 'articles',
        as         => 'articles',
        join       => 'left',
        constraint => [
            'articles.author_id' => \'`authors`.`id`',
            'articles.type'      => \'article'
        ]
    }
);
