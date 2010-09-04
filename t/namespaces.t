#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 16;

use lib 't/lib';

use TestEnv;
use Schema::AuthorData;

TestEnv->setup;

Schema::AuthorData->populate;


my $authors = Schema::Author->find(
    rows_as_object => 1,
    with           => ['articles.comments']
);
is(ref $authors->row(0)->articles->row(0), 'Schema::Article');
is(ref $authors->row(0)->articles->row(0)->comments->row(0),
    'Schema::Comment');


# one-to-many
is(Schema::Article->schema->relationship('comments')->foreign_class,
    'Schema::Comment');
is(Schema::Article->schema->relationship('comments')->foreign_table,
    'comments');
is(Schema::Article->schema->relationship('comments')->class,
    'Schema::Article');


# many-to-one
is(Schema::Comment->schema->relationship('article')->foreign_class,
    'Schema::Article');
is(Schema::Comment->schema->relationship('article')->foreign_table,
    'articles');
is(Schema::Comment->schema->relationship('article')->class,
    'Schema::Comment');


# many-to-many
is(Schema::Article->schema->relationship('tags')->map_class,
    'Schema::ArticleTagMap');
is(Schema::Article->schema->relationship('tags')->foreign_class,
    'Schema::Tag');
is(Schema::Article->schema->relationship('tags')->foreign_table, 'tags');
is(Schema::Article->schema->relationship('tags')->class, 'Schema::Article');

is(Schema::Tag->schema->relationship('articles')->map_class,
    'Schema::ArticleTagMap');
is(Schema::Tag->schema->relationship('articles')->foreign_class,
    'Schema::Article');
is(Schema::Tag->schema->relationship('articles')->foreign_table, 'articles');
is(Schema::Tag->schema->relationship('articles')->class, 'Schema::Tag');


#is(ref $authors[0]->tags->[0], 'Schema::Tag'); ### TO DO in ObjectDB


Schema::AuthorData->cleanup;

TestEnv->teardown;
