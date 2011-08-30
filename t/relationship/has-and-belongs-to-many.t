#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 18;

use_ok('ObjectDB::Relationship::HasAndBelongsToMany');

use lib 't/lib';

use TestDB;
use TestEnv;
TestEnv->setup;

my $rel = ObjectDB::Relationship::HasAndBelongsToMany->new(
    class => 'Article',
    name  => 'tags',
);
ok($rel);

is($rel->type, 'has_and_belongs_to_many');
ok($rel->is_has_and_belongs_to_many);

$rel->build(TestDB->dbh);

is($rel->foreign_table, 'tags');

is($rel->map_from, 'article');
is($rel->map_to,   'tag');

is_deeply(
    $rel->to_map_source,
    {   name       => 'article_tag_maps',
        join       => 'left',
        constraint => ['articles.id' => \'`article_tag_maps`.`article_id`']
    }
);

is_deeply(
    $rel->to_self_map_source,
    {   name       => 'article_tag_maps',
        join       => 'left',
        constraint => ['tags.id' => \'`article_tag_maps`.`tag_id`']
    }
);

is_deeply(
    $rel->to_source,
    {   name       => 'tags',
        as         => 'tags',
        join       => 'left',
        constraint => ['tags.id' => \'`article_tag_maps`.`tag_id`']
    }
);

is_deeply(
    $rel->to_self_source,
    {   name       => 'articles',
        as         => 'articles',
        join       => 'left',
        constraint => ['articles.id' => \'`article_tag_maps`.`article_id`']
    }
);

$rel = ObjectDB::Relationship::HasAndBelongsToMany->new(
    class => 'Tag',
    name  => 'articles',
);
ok($rel);

is($rel->type, 'has_and_belongs_to_many');
ok($rel->is_has_and_belongs_to_many);

$rel->build(TestDB->dbh);

is($rel->foreign_table, 'articles');

is($rel->map_from, 'tag');
is($rel->map_to,   'article');

is_deeply(
    $rel->to_map_source,
    {   name       => 'article_tag_maps',
        join       => 'left',
        constraint => ['tags.id' => \'`article_tag_maps`.`tag_id`']
    }
);
