#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 47;

use lib 't/lib';

use TestDB;

use Author;
use Article;

my $conn = TestDB->conn;

my $author = Author->create(
    conn     => $conn,
    name     => 'foo',
    articles => [{title => 'bar'}, {title => 'baz'}]
);
is(@{$author->articles},                    2);
is($author->articles->[0]->column('title'), 'bar');
is($author->articles->[1]->column('title'), 'baz');

$author = Author->find(conn => $conn, id => $author->id);
my @articles = $author->articles;
is(@articles,                     2);
is($articles[0]->column('title'), 'bar');
is($articles[1]->column('title'), 'baz');

$author = Author->find(conn => $conn, id => $author->id);
ok($author->delete_related('articles' => where => [title => 'bar']));
@articles = $author->articles;
is(@articles,                     1);
is($articles[0]->column('title'), 'baz');

@articles = $author->create_related(articles => {title => 'bar'});
is(@articles,                     1);
is($articles[0]->column('title'), 'bar');

$author = Author->find(conn => $conn, id => $author->id);
my $article =
  $author->find_related('articles' => where => [title => 'bar'])->next;
ok($article);
is($article->column('title'), 'bar');

$author->delete(conn => $conn);
ok(!Article->find(conn => $conn)->next);

$author = Author->create(conn => $conn, name => 'spammer');

$author = Author->create(
    conn     => $conn,
    name     => 'foo',
    articles => [
        {   title    => 'bar',
            comments => [
                {author_id => $author->id, content => 'foo'},
                {author_id => $author->id, content => 'bar'}
            ]
        },
        {   title    => 'baz',
            comments => {author_id => $author->id, content => 'baz'}
        }
    ]
);

@articles =
  Author->find_related('articles', conn => $conn, ids => [$author->id]);
is(@articles, 2);

$author = Author->find(conn => $conn, id => $author->id, with => 'articles');
is(@{$author->articles},                    2);
is($author->articles->[0]->column('title'), 'bar');
is($author->articles->[1]->column('title'), 'baz');

$author = Author->find(
    conn => $conn,
    id   => $author->id,
    with => [qw/articles.comments/]
);
is(@{$author->articles}, 2);
ok(not defined $author->articles->[0]->column('title'));
is(@{$author->articles->[0]->comments}, 2);
ok(not defined $author->articles->[1]->column('title'));
is(@{$author->articles->[1]->comments}, 1);

# Also works for list of authors
my @authors = Author->find(conn=>$conn, with => [qw/articles.comments/]);
ok(not defined $authors[1]->articles->[0]->column('title') );
is(@{$authors[1]->articles->[0]->comments}, 2);

$author = Author->find(
    conn => $conn,
    id   => $author->id,
    with => [qw/articles articles.comments/]
);
is(@{$author->articles},                    2);
is($author->articles->[0]->column('title'), 'bar');
is(@{$author->articles->[0]->comments},     2);
is($author->articles->[1]->column('title'), 'baz');
is(@{$author->articles->[1]->comments},     1);

$author = Author->find(
    conn => $conn,
    id   => $author->id,
    with => [qw/articles articles.comments articles.comments.author/]
);
is(@{$author->articles},                                          2);
is($author->articles->[0]->column('title'),                       'bar');
is(@{$author->articles->[0]->comments},                           2);
is($author->articles->[0]->comments->[0]->author->column('name'), 'spammer');
is($author->articles->[0]->comments->[1]->author->column('name'), 'spammer');
is($author->articles->[1]->column('title'),                       'baz');
is(@{$author->articles->[1]->comments},                           1);
is($author->articles->[0]->comments->[0]->author->column('name'), 'spammer');

@authors = Author->find(
    conn  => $conn,
    where => [id => $author->id],
    with  => [qw/articles articles.comments articles.comments.author/]
);
is(@authors,                                    1);
is(@{$authors[0]->articles},                    2);
is($authors[0]->articles->[0]->column('title'), 'bar');
is(@{$authors[0]->articles->[0]->comments},     2);
is($authors[0]->articles->[0]->comments->[0]->author->column('name'),
    'spammer');
is($authors[0]->articles->[0]->comments->[1]->author->column('name'),
    'spammer');
is($authors[0]->articles->[1]->column('title'), 'baz');
is(@{$authors[0]->articles->[1]->comments},     1);
is($authors[0]->articles->[0]->comments->[0]->author->column('name'),
    'spammer');

Author->delete(conn => $conn);
