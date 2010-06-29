#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;

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
is(ArticleTagMap->count(conn => $conn), 0);
is(Tag->count(conn => $conn), 2);
Tag->delete(conn => $conn);
