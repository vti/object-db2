#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 16;

use lib 't/lib';

use TestEnv;
use AuthorData;

TestEnv->setup;

AuthorData->populate;


# Pass full method name: inflate_us_date_format
my @comments =
  Comment->find(inflate => [Comment => 'inflate_us_date_format']);
is(@comments,                                              10);
is($comments[0]->column('creation_date'),                  '2005-12-01');
is($comments[0]->virtual_column('creation_date_formated'), 'Dec 1,2005');


# Pass short method name: us_date_format
@comments = Comment->find(inflate => [Comment => 'us_date_format']);
is(@comments,                                              10);
is($comments[0]->column('creation_date'),                  '2005-12-01');
is($comments[0]->virtual_column('creation_date_formated'), 'Dec 1,2005');


# Pass specific id
my $comment = Comment->find(
    inflate => [Comment => 'us_date_format'],
    id      => 1
);
is($comment->column('creation_date'),                  '2005-12-01');
is($comment->virtual_column('creation_date_formated'), 'Dec 1,2005');


# Inflate related objects (one to many)
my @authors = Author->find(
    with    => ['articles.comments'],
    inflate => [Comment => 'us_date_format']
);
is($authors[0]->articles->[0]->comments->[0]->column('creation_date'),
    '2005-12-01');
is( $authors[0]->articles->[0]->comments->[0]
      ->virtual_column('creation_date_formated'),
    'Dec 1,2005'
);


# Pass specific id
my $author = Author->find(
    with    => ['articles.comments'],
    inflate => [Comment => 'us_date_format'],
    id      => 1
);
is($author->articles->[0]->comments->[0]->column('creation_date'),
    '2005-12-01');
is( $author->articles->[0]->comments->[0]
      ->virtual_column('creation_date_formated'),
    'Dec 1,2005'
);


# Inflate related object (one to one)
my @articles = Article->find(
    with    => ['main_category'],
    inflate => [MainCategory => 'quote_title']
);
is($articles[0]->main_category->column('title'), 'main category 4');
is($articles[0]->main_category->virtual_column('quoted_title'),
    '"main category 4"');


# Pass specific id
my $article = Article->find(
    with    => ['main_category'],
    inflate => [MainCategory => 'quote_title'],
    id      => 1
);
is($article->main_category->column('title'), 'main category 4');
is($article->main_category->virtual_column('quoted_title'),
    '"main category 4"');


AuthorData->cleanup;

TestEnv->teardown;
