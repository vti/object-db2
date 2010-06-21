#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 18;

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
$article->author->update;
$article = Article->find(dbh => $dbh, id => $article->id, with => 'author');
is($article->author->column('name'), 'baz', 'related object is updated');

$article = Article->find(dbh => $dbh, id => $article->id);
$author = $article->find_related('author');
ok($author, 'related object is prefetched');
is($author->column('name'), 'baz', 'related object has right columns');

ok($article->delete, 'delete object');
ok(!Article->find(dbh => $dbh, id => $article->id), 'object not available');
ok(Author->find(dbh => $dbh, id => $author->id), 'related object available');
Author->delete(dbh => $dbh);
Article->delete(dbh => $dbh);

$author = Author->create(dbh => $dbh, name => 'foo');
Article->create(dbh => $dbh, title => 'foo', authors_id => $author->id);
$author = Author->create(dbh => $dbh, name => 'bar');
Article->create(dbh => $dbh, title => 'bar', authors_id => $author->id);
$author = Author->create(dbh => $dbh, name => 'baz');
Article->create(dbh => $dbh, title => 'baz', authors_id => $author->id);

my @articles = Article->find(dbh => $dbh, where => ['author.name' => 'foo']);
is(@articles, 1);
ok(!$articles[0]->{related}->{author});
is($articles[0]->author->column('name'), 'foo');

@articles = Article->find(dbh => $dbh, where => ['author.name' => 'baz'], with => 'author');
is(@articles, 1);
ok($articles[0]->{related}->{author});
is($articles[0]->author->column('name'), 'baz');

Article->delete(dbh => $dbh);
Author->delete(dbh => $dbh);
