#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 9;

use_ok('ObjectDB::Relationship::HasAndBelongsToMany');

use lib 't/lib';

use TestDB;

my $rel = ObjectDB::Relationship::HasAndBelongsToMany->new(
    class => 'Article',
    name  => 'tags',
);
ok($rel);

$rel->build(TestDB->conn);

is($rel->foreign_table, 'tags');

is($rel->map_from, 'article');
is($rel->map_to, 'tag');

is_deeply(
    $rel->to_map_source,
    {   name       => 'article_tag_maps',
        join       => 'left',
        constraint => ['articles.id' => 'article_tag_maps.articles_id']
    }
);

is_deeply(
    $rel->to_self_map_source,
    {   name       => 'article_tag_maps',
        join       => 'left',
        constraint => ['tags.id' => 'article_tag_maps.tags_id']
    }
);

is_deeply(
    $rel->to_source,
    {   name       => 'tags',
        as         => 'tags',
        join       => 'left',
        constraint => ['tags.id' => 'article_tag_maps.tags_id']
    }
);

is_deeply(
    $rel->to_self_source,
    {   name       => 'articles',
        as         => 'articles',
        join       => 'left',
        constraint => ['articles.id' => 'article_tag_maps.articles_id']
    }
);
