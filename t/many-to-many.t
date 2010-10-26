#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 17;

use lib 't/lib';

use TestEnv;

use Article;

TestEnv->setup;

my $article = Article->create(
    title => 'foo',
    tags  => [{name => 'bar'}, {name => 'baz'}]
);

is(Tag->count, 2, 'related objects created');
is(ArticleTagMap->count(conn => TestDB->init_conn),
    2, 'mapping objects created');

Article->delete;

is(ArticleTagMap->count(conn => TestDB->init_conn),
    0, 'mapping objects are deleted');
is(Tag->count, 2, 'related objects are stil there');

Tag->delete;

$article = Article->create(title => 'foo');
$article->create_related(tags => [{name => 'bar'}, {name => 'baz'}]);
is(ArticleTagMap->count(conn => TestDB->init_conn), 2);

$article->delete_related(tags => where => ['tags.name' => 'foo']);
is(ArticleTagMap->count(conn => TestDB->init_conn), 2);

$article->delete_related(tags => where => ['tags.name' => 'bar']);
is(ArticleTagMap->count(conn => TestDB->init_conn), 1);

$article->delete_related('tags');
is(ArticleTagMap->count(conn => TestDB->init_conn), 0);

$article->create_related(tags => [{name => 'bar'}, {name => 'baz'}]);

# Create a second article to make tests more solid
my $article2 = Article->create(title => 'foo2');
$article2->create_related(tags => [{name => 'bar2'}, {name => 'baz2'}]);


my @articles = Article->find(where => ['tags.name' => 'foo']);
is(@articles, 0);

@articles = Article->find(where => ['tags.name' => 'bar']);
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

Article->delete;
Tag->delete;

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
