#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 14;

use lib 't/lib';

use TestDB;

use Author;
use Article;

my $dbh = TestDB->dbh;

my $author = Author->create(
    dbh      => $dbh,
    name     => 'foo',
    articles => [{title => 'bar'}, {title => 'baz'}]
);
is(@{$author->articles}, 2);
is($author->articles->[0]->column('title'), 'bar');
is($author->articles->[1]->column('title'), 'baz');

$author = Author->find(dbh => $dbh, id => $author->id);
my @articles = $author->articles;
is(@articles, 2);
is($articles[0]->column('title'), 'bar');
is($articles[1]->column('title'), 'baz');

$author = Author->find(dbh => $dbh, id => $author->id);
ok($author->delete_related('articles' => where => [title => 'bar']));
@articles = $author->articles;
is(@articles, 1);
is($articles[0]->column('title'), 'baz');

@articles = $author->create_related(articles => {title => 'bar'});
is(@articles, 1);
is($articles[0]->column('title'), 'bar');

$author = Author->find(dbh => $dbh, id => $author->id);
my $article = $author->find_related('articles' => where => [title => 'bar'])->next;
ok($article);
is($article->column('title'), 'bar');

$author->delete(dbh => $dbh);
ok(!Article->find(dbh => $dbh)->next);
