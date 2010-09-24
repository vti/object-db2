#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 13;

use lib 't/lib';


use TestEnv;
TestEnv->setup;


use AuthorData;
my ($author1, $author2) = AuthorData->populate;


# Make sure that data is prefetched
$ENV{OBJECTDB_FORCE_PREFETCH} = 1;


### One primary or unique key column

# Pass primary key as single value
my $author = Author->find(id => $author2->column('id'));
is($author->column('name'), 'author 2');


# Pass primary key as hash ref
$author = Author->find(id => {id => $author2->column('id')});
is($author->column('name'), 'author 2');


# Pass primary key as array ref
$author = Author->find(id => [id => $author2->column('id')]);
is($author->column('name'), 'author 2');


# Pass invalid column (no primary key nor unique key) to throw an exception
eval { $author = Author->find(id => {password => 'some pass' }) };
my $err_msg = 'FIND: passed columns do not form primary or unique key';
ok($@ =~ m/\Q$err_msg/, "throw exception: $err_msg");


# Pass unique key as hash ref
$author = Author->find(id => {name => 'author 2'});
is($author->column('name'), 'author 2');
is($author->column('id'), $author2->id);


# Pass unique key as array ref
$author = Author->find(id => [name => 'author 2']);
is($author->column('name'), 'author 2');
is($author->column('id'), $author2->id);


# Make sure that where clause is IGNORED
# POSSIBLE ALTERNATIVE: THROW AN EXCEPTION
$author = Author->find(id => $author2->column('id'), where => [ name => 'author 1' ]);
is($author->column('name'), 'author 2');


# With prefetch
$author = Author->find(id => $author2->column('id'), with => [qw/articles articles.comments/]);
is($author->column('name'), 'author 2');
is($author->articles->[0]->column('title'), 'article 2-1');
is($author->articles->[1]->column('title'), 'article 2-2');
is($author->articles->[0]->comments->[0]->column('content'),
    'comment 2-1-1');



### TO DO: primary or unique key with multiple columns



# Allow lazy loading of data
$ENV{OBJECTDB_FORCE_PREFETCH} = 0;

AuthorData->cleanup;

TestEnv->teardown;
