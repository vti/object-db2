#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 8;

use lib 't/lib';

use TestEnv;
use Schema::AuthorData;

TestEnv->setup;

Schema::AuthorData->populate;


my @authors = Schema::Author->find(
    with    => ['articles.comments']
);
is(ref $authors[0]->articles->[0], 'Schema::Article');
is(ref $authors[0]->articles->[0]->comments->[0], 'Schema::Comment');

is(Schema::Article->schema->relationship('tags')->map_class, 'Schema::ArticleTagMap');
is(Schema::Article->schema->relationship('tags')->foreign_class, 'Schema::Tag');
is(Schema::Article->schema->relationship('tags')->class, 'Schema::Article');

is(Schema::Tag->schema->relationship('articles')->map_class, 'Schema::ArticleTagMap');
is(Schema::Tag->schema->relationship('articles')->foreign_class, 'Schema::Article');
is(Schema::Tag->schema->relationship('articles')->class, 'Schema::Tag');

#is(ref $authors[0]->tags->[0], 'Schema::Tag'); ### TO DO in ObjectDB


Schema::AuthorData->cleanup;

TestEnv->teardown;
