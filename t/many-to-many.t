#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 17;

use lib 't/lib';

use TestEnv;
use TestDB;

use Article;

TestEnv->setup;

my $article = Article->new->set_columns(
    title => 'foo',
    tags  => [{name => 'bar'}, {name => 'baz'}]
)->create;

is(Tag->new->count, 2, 'related objects created');
is(ArticleTagMap->new(conn => TestDB->conn)->count,
    2, 'mapping objects created');

Article->new->delete(all => 1);

is(ArticleTagMap->new(conn => TestDB->conn)->count,
    0, 'mapping objects are deleted');
is(Tag->new->count, 2, 'related objects are stil there');

Tag->new->delete(all => 1);

$article = Article->new->set_columns(title => 'foo')->create;
$article->create_related(tags => [{name => 'bar'}, {name => 'baz'}]);
is(ArticleTagMap->new(conn => TestDB->conn)->count, 2);

$article->delete_related(tags => where => ['tags.name' => 'foo']);
is(ArticleTagMap->new(conn => TestDB->conn)->count, 2);

$article->delete_related(tags => where => ['tags.name' => 'bar']);
is(ArticleTagMap->new(conn => TestDB->conn)->count, 1);

$article->delete_related('tags');
is(ArticleTagMap->new(conn => TestDB->conn)->count, 0);

$article->create_related(tags => [{name => 'bar'}, {name => 'baz'}]);

# Create a second article to make tests more solid
my $article2 = Article->new->set_columns(title => 'foo2')->create;
$article2->create_related(tags => [{name => 'bar2'}, {name => 'baz2'}]);


my @articles = Article->new->find(where => ['tags.name' => 'foo']);
is(@articles, 0);

@articles = Article->new->find(where => ['tags.name' => 'bar']);
is(@articles, 1);


my @tags = $article->find_related('tags', where => [name => 'foo']);
is(@tags, 0);

@tags = $article->find_related('tags', where => [name => 'bar']);
is(@tags, 1);
is($tags[0]->column('name'), 'bar' );

@tags = $article->find_related('tags', where => [name => 'bar2']);
is(@tags, 0);

@tags = $article2->find_related('tags', where => [name => 'bar2']);
is(@tags, 1);



@tags = $article->find_related('tags');
is(@tags,                    2);
is($tags[0]->column('name'), 'bar');

Article->new->delete(all => 1);
Tag->new->delete(all => 1);

#$article = Article->create(
#conn      => $conn,
#title     => 'foo',
#tags => [{name => 'bar'}, {name => 'baz'}]
#);

#Article->find(conn => $conn, with => 'tags');
#is($article->tags->[0]->column('name'), '');

#Article->delete(conn => $conn);
#Tag->delete(conn => $conn);

TestEnv->teardown;
