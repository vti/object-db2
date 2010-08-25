#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 32;

use lib 't/lib';

use TestEnv;

use Author;
use Article;
use Comment;

TestEnv->setup;

my $conn = TestDB->conn;

my $article = Article->find(id => 999, with => 'author');
ok(!$article, 'unknown id');

my $author = Author->create(name => 'foo');
$article = Article->create(author_id => $author->id, title => 'bar');

$article = Article->find(id => $article->id, with => 'author');
ok($article, 'find with related object');
is($article->column('title'), 'bar', 'object loaded');
ok($article->author, 'related object loaded');
is($article->author->column('name'),
    'foo', 'related object has right columns');

$article->author->column(name => 'baz');
ok($article->author->is_modified, 'related object is modified');
$article->author->update;
$article = Article->find(id => $article->id, with => 'author');
is($article->author->column('name'), 'baz', 'related object is updated');

$article = Article->find(id => $article->id);
$author = $article->find_related('author');
ok($author, 'related object is prefetched');
is($author->column('name'), 'baz', 'related object has right columns');

ok($article->delete, 'delete object');
ok(!Article->find(id => $article->id), 'object not available');
ok(Author->find(id => $author->id), 'related object available');
Author->delete;
Article->delete;

$author = Author->create(name => 'foo');
Article->create(title => 'foo', author_id => $author->id);
$author = Author->create(name => 'bar');
Article->create(title => 'bar', author_id => $author->id);
$author = Author->create(name => 'baz');
Article->create(title => 'baz', author_id => $author->id);

my @articles = Article->find(where => ['author.name' => 'foo']);
is(@articles, 1);
ok(!$articles[0]->{related}->{author});
is($articles[0]->author->column('name'), 'foo');

@articles = Article->find(
    where => ['author.name' => 'baz'],
    with  => 'author'
);
is(@articles, 1);
ok($articles[0]->{related}->{author});
is($articles[0]->author->column('name'), 'baz');

@articles = Article->find(
    where => ['author.name' => 'baz'],
    with  => ['author'      => {columns => 'id'}]
);
is(@articles, 1);
ok($articles[0]->{related}->{author});
ok(not defined $articles[0]->author->column('name'));

Article->delete;
Author->delete;

$author = Author->create(
    name     => 'foo',
    articles => {title => 'bar', comments => {content => 'baz'}}
);
my @comments = Comment->find(with => 'article');
is(@comments,                              1);
is($comments[0]->column('content'),        'baz');
is($comments[0]->article->column('title'), 'bar');

@comments = Comment->find(with => 'article.author');
is(@comments,                       1);
is($comments[0]->column('content'), 'baz');
ok(not defined $comments[0]->article->column('title'));
is($comments[0]->article->author->column('name'), 'foo');

@comments = Comment->find(with => [qw/article article.author/]);
is(@comments,                                     1);
is($comments[0]->column('content'),               'baz');
is($comments[0]->article->column('title'),        'bar');
is($comments[0]->article->author->column('name'), 'foo');

Comment->delete;
Article->delete;
Author->delete;

TestEnv->teardown;
