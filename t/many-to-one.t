#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 12;

use lib 't/lib';

use TestDB;

use Author;
use Article;

my $dbh = TestDB->dbh;

my $article = Article->find(dbh => $dbh, id => 999, with => 'author');
ok(!$article, 'unknown id');

my $author = Author->create(dbh => $dbh, name => 'foo');
$article =
  Article->create(dbh => $dbh, authors_id => $author->id, title => 'bar');

$article = Article->find(dbh => $dbh, id => $article->id, with => 'author');
ok($article, 'find with related object');
is($article->column('title'), 'bar', 'object loaded');
ok($article->author, 'related object loaded');
is($article->author->column('name'), 'foo', 'related object has right columns');

$article->author->column(name => 'baz');
ok($article->author->is_modified, 'related object is modified');
$article->update;
$article = Article->find(dbh => $dbh, id => $article->id, with => 'author');
is($article->author->column('name'), 'baz', 'related object is updated');

$article = Article->find(dbh => $dbh, id => $article->id);
$article->find_related('author');
ok($article->author, 'related object is prefetched');
is($article->author->column('name'), 'baz', 'related object has right columns');

ok($article->delete, 'delete object');
ok(!Article->find(dbh => $dbh, id => $article->id), 'object not available');
ok(Author->find(dbh => $dbh, id => $author->id), 'related object available');
$author->delete;
