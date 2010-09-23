#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 9;

use lib 't/lib';


use TestEnv;
TestEnv->setup;


use AuthorData;
my ($author1, $author2) = AuthorData->populate;


# Make sure that data is prefetched
$ENV{OBJECTDB_FORCE_PREFETCH} = 1;


# First simple test
my $authors_table = Author->new;
my @authors = $authors_table->find;
is(@authors, 2);
is($authors[0]->column('id'), $author1->column('id') );


# Returned object should NOT be table object
isnt($authors[0], $authors_table);
isnt($authors[1], $authors_table);


# Pass specific author id
$authors_table = Author->new;
my $author = $authors_table->find( id => $author1->column('id') );
is($author->column('name'), 'author 1');


# Returned object should NOT be table object
isnt($author, $authors_table);


# Where
$authors_table = Author->new;
@authors = $authors_table->find(where => [name => 'author 1']);
is(@authors, 1);
is($author->column('name'), 'author 1');


# Prefetch
$authors_table = Author->new;
@authors = $authors_table->find(with => [qw/articles.comments/]);
is($authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment 1-1-1');


# Allow lazy loading of data
$ENV{OBJECTDB_FORCE_PREFETCH} = 0;

AuthorData->cleanup;

TestEnv->teardown;
