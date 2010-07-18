#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;

use lib 't/lib';

use TestDB;

use Article;

my $conn = TestDB->conn;

my $article = Article->create(
    conn      => $conn,
    title     => 'foo',
    tags => [{name => 'bar'}, {name => 'baz'}]
);

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

Article->delete(conn => $conn);
Tag->delete(conn => $conn);

$article = Article->create(
    conn      => $conn,
    title     => 'foo',
    tags => [{name => 'bar'}, {name => 'baz'}]
);

Article->delete(conn => $conn);
Tag->delete(conn => $conn);
