#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 21;

use lib 't/lib';

use TestDB;

use Author;
use Article;

my $conn = TestDB->conn;

my $article = Article->find(conn => $conn, id => 999, with => 'author');
ok(!$article, 'unknown id');

my $author = Author->create(conn => $conn, name => 'foo');
$article =
  Article->create(conn => $conn, authors_id => $author->id, title => 'bar');

$article = Article->find(conn => $conn, id => $article->id, with => 'author');
ok($article, 'find with related object');
is($article->column('title'), 'bar', 'object loaded');
ok($article->author, 'related object loaded');
is($article->author->column('name'),
    'foo', 'related object has right columns');

$article->author->column(name => 'baz');
ok($article->author->is_modified, 'related object is modified');
$article->author->update;
$article = Article->find(conn => $conn, id => $article->id, with => 'author');
is($article->author->column('name'), 'baz', 'related object is updated');

$article = Article->find(conn => $conn, id => $article->id);
$author = $article->find_related('author');
ok($author, 'related object is prefetched');
is($author->column('name'), 'baz', 'related object has right columns');

ok($article->delete, 'delete object');
ok(!Article->find(conn => $conn, id => $article->id), 'object not available');
ok(Author->find(conn => $conn, id => $author->id),
    'related object available');
Author->delete(conn => $conn);
Article->delete(conn => $conn);

$author = Author->create(conn => $conn, name => 'foo');
Article->create(conn => $conn, title => 'foo', authors_id => $author->id);
$author = Author->create(conn => $conn, name => 'bar');
Article->create(conn => $conn, title => 'bar', authors_id => $author->id);
$author = Author->create(conn => $conn, name => 'baz');
Article->create(conn => $conn, title => 'baz', authors_id => $author->id);

my @articles =
  Article->find(conn => $conn, where => ['author.name' => 'foo']);
is(@articles, 1);
ok(!$articles[0]->{related}->{author});
is($articles[0]->author->column('name'), 'foo');

@articles = Article->find(
    conn  => $conn,
    where => ['author.name' => 'baz'],
    with  => 'author'
);
is(@articles, 1);
ok($articles[0]->{related}->{author});
is($articles[0]->author->column('name'), 'baz');

@articles = Article->find(
    conn  => $conn,
    where => ['author.name' => 'baz'],
    with  => ['author' => {columns => 'id'}]
);
is(@articles, 1);
ok($articles[0]->{related}->{author});
ok(not defined $articles[0]->author->column('name'));

Article->delete(conn => $conn);
Author->delete(conn => $conn);
