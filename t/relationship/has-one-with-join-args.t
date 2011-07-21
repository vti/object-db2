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
    class     => 'Author',
    name      => 'article',
    join_args => [title => 'foo', content => 'bar']
);
ok($rel);

is($rel->type, 'has_one');
ok($rel->is_has_one);

$rel->build(TestDB->init_conn);

is($rel->foreign_table, 'articles');

is_deeply(
    $rel->to_source,
    {   name       => 'articles',
        as         => 'articles',
        join       => 'left',
        constraint => [
            'articles.author_id' => \'`authors`.`id`',
            'articles.title'     => 'foo',
            'articles.content'   => 'bar'
        ]
    }
);

