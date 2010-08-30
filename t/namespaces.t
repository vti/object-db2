#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;

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
#is(ref $authors[0]->tags->[0], 'Schema::Tag'); ### TO DO in ObjectDB


Schema::AuthorData->cleanup;

TestEnv->teardown;
