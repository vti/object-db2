#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 13;

use lib 't/lib';

use TestDB;

use Article;

my $conn = TestDB->conn;

my $article = Article->create(
    conn      => $conn,
    title     => 'foo',
    tags => [{name => 'bar'}, {name => 'baz'}]
);

is(Tag->count(conn => $conn), 2, 'related objects created');
is(ArticleTagMap->count(conn => $conn), 2, 'mapping objects created');

Article->delete(conn => $conn);

is(ArticleTagMap->count(conn => $conn), 0, 'mapping objects are deleted');
is(Tag->count(conn => $conn), 2, 'related objects are stil there');

Tag->delete(conn => $conn);

$article = Article->create(conn => $conn, title => 'foo');
$article->create_related(tags => [{name => 'bar'}, {name => 'baz'}]);
is(ArticleTagMap->count(conn => $conn), 2);

$article->delete_related(tags => where => ['tags.name' => 'foo']);
is(ArticleTagMap->count(conn => $conn), 2);

$article->delete_related(tags => where => ['tags.name' => 'bar']);
is(ArticleTagMap->count(conn => $conn), 1);

$article->delete_related('tags');
is(ArticleTagMap->count(conn => $conn), 0);

$article->create_related(tags => [{name => 'bar'}, {name => 'baz'}]);

my @articles = Article->find(conn => $conn, where => ['tags.name' => 'foo']);
is(@articles, 0);

@articles = Article->find(conn => $conn, where => ['tags.name' => 'bar']);
is(@articles, 1);

my @tags = $article->find_related('tags', where => [name => 'foo']);
is(@tags, 0);

@tags = $article->find_related('tags');
is(@tags, 2);
is($tags[0]->column('name'), 'bar');

Article->delete(conn => $conn);
Tag->delete(conn => $conn);

#$article = Article->create(
    #conn      => $conn,
    #title     => 'foo',
    #tags => [{name => 'bar'}, {name => 'baz'}]
#);

#Article->find(conn => $conn, with => 'tags');
#is($article->tags->[0]->column('name'), '');

#Article->delete(conn => $conn);
#Tag->delete(conn => $conn);
