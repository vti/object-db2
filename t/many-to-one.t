#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 33;

use lib 't/lib';

use TestEnv;

use Author;
use Article;
use Comment;

TestEnv->setup;

my $article = Article->new->find(id => 999, with => 'author');
ok(!$article, 'unknown id');

my $author = Author->new->create(name => 'foo');
$article = Article->new->create(author_id => $author->id, title => 'bar');

$article = Article->new->find(id => $article->id, with => 'author');
ok($article, 'find with related object');
is($article->column('title'), 'bar', 'object loaded');
ok($article->author, 'related object loaded');
is($article->author->column('name'),
    'foo', 'related object has right columns');
is_deeply(
    $article->to_hash,
    {   id                => $article->id,
        author_id         => $author->id,
        title             => 'bar',
        main_category_id  => undef,
        category_id       => undef,
        special_report_id => undef,
        author => {id => $author->id, name => 'foo', password => ''}
    }
);

$article->author->column(name => 'baz');
ok($article->author->is_modified, 'related object is modified');
$article->author->update;
$article = Article->new->find(id => $article->id, with => 'author');
is($article->author->column('name'), 'baz', 'related object is updated');

$article = Article->new->find(id => $article->id);
$author = $article->find_related('author');
ok($author, 'related object is prefetched');
is($author->column('name'), 'baz', 'related object has right columns');

ok($article->delete, 'delete object');
ok(!Article->new->find(id => $article->id), 'object not available');
ok(Author->new->find(id => $author->id), 'related object available');
Author->new->delete(all => 1);
Article->new->delete(all => 1);

$author = Author->new->create(name => 'foo');
Article->new->create(title => 'foo', author_id => $author->id);
$author = Author->new->create(name => 'bar');
Article->new->create(title => 'bar', author_id => $author->id);
$author = Author->new->create(name => 'baz');
Article->new->create(title => 'baz', author_id => $author->id);

my @articles = Article->new->find(where => ['author.name' => 'foo']);
is(@articles, 1);
ok(!$articles[0]->{related}->{author});
is($articles[0]->author->column('name'), 'foo');

@articles = Article->new->find(
    where => ['author.name' => 'baz'],
    with  => 'author'
);
is(@articles, 1);
ok($articles[0]->{related}->{author});
is($articles[0]->author->column('name'), 'baz');

@articles = Article->new->find(
    where => ['author.name' => 'baz'],
    with  => ['author'      => {columns => 'id'}]
);
is(@articles, 1);
ok($articles[0]->{related}->{author});
ok(not defined $articles[0]->author->column('name'));

Article->new->delete(all => 1);
Author->new->delete(all => 1);

$author = Author->new->create(
    name     => 'foo',
    articles => {title => 'bar', comments => {content => 'baz'}}
);
my @comments = Comment->new->find(with => 'article');
is(@comments,                              1);
is($comments[0]->column('content'),        'baz');
is($comments[0]->article->column('title'), 'bar');

@comments = Comment->new->find(with => 'article.author');
is(@comments,                       1);
is($comments[0]->column('content'), 'baz');
ok(not defined $comments[0]->article->column('title'));
is($comments[0]->article->author->column('name'), 'foo');

@comments = Comment->new->find(with => [qw/article article.author/]);
is(@comments,                                     1);
is($comments[0]->column('content'),               'baz');
is($comments[0]->article->column('title'),        'bar');
is($comments[0]->article->author->column('name'), 'foo');

Comment->new->delete(all => 1);
Article->new->delete(all => 1);
Author->new->delete(all => 1);

TestEnv->teardown;
