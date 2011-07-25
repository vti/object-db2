#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 16;

use lib 't/lib';

use TestEnv;
use Schema::AuthorData;

TestEnv->setup;

my $conn = TestDB->conn;


# one-to-many
use Schema::Article;
Schema::Article->schema->relationship('comments')->build($conn);
is(Schema::Article->schema->relationship('comments')->foreign_class,
    'Schema::Comment');
is(Schema::Article->schema->relationship('comments')->foreign_table,
    'comments');
is(Schema::Article->schema->relationship('comments')->class,
    'Schema::Article');


# many-to-one
use Schema::Comment;
Schema::Comment->schema->relationship('article')->build($conn);
is(Schema::Comment->schema->relationship('article')->foreign_class,
    'Schema::Article');
is(Schema::Comment->schema->relationship('article')->foreign_table,
    'articles');
is(Schema::Comment->schema->relationship('article')->class,
    'Schema::Comment');


# many-to-many
Schema::Article->schema->relationship('tags')->build($conn);
is(Schema::Article->schema->relationship('tags')->map_class,
    'Schema::ArticleTagMap');
is(Schema::Article->schema->relationship('tags')->foreign_class,
    'Schema::Tag');
is(Schema::Article->schema->relationship('tags')->foreign_table, 'tags');
is(Schema::Article->schema->relationship('tags')->class, 'Schema::Article');


use Schema::Tag;
Schema::Tag->schema->relationship('articles')->build($conn);
is(Schema::Tag->schema->relationship('articles')->map_class,
    'Schema::ArticleTagMap');
is(Schema::Tag->schema->relationship('articles')->foreign_class,
    'Schema::Article');
is(Schema::Tag->schema->relationship('articles')->foreign_table, 'articles');
is(Schema::Tag->schema->relationship('articles')->class, 'Schema::Tag');


Schema::AuthorData->populate;

my @authors = Schema::Author->new->find(with => ['articles.comments']);
is(ref $authors[0]->articles->[0],                'Schema::Article');
is(ref $authors[0]->articles->[0]->comments->[0], 'Schema::Comment');

#is(ref $authors[0]->tags->[0], 'Schema::Tag'); ### TO DO in ObjectDB


Schema::AuthorData->cleanup;

TestEnv->teardown;
