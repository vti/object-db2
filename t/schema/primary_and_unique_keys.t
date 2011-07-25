#!/usr/bin/env perl

use lib 't/lib';

package MultiPrimary;
use base 'TestDB';
__PACKAGE__->schema->columns(qw/foo bar other/)->primary_key(qw/foo bar/);

package MultiUnique;
use base 'TestDB';
__PACKAGE__->schema->columns(qw/id first_name last_name age city street/)
  ->primary_key(qw/id/)
  ->unique_keys([qw/first_name last_name/], [qw/city street/]);


package main;

use strict;
use warnings;

use Test::More tests => 17;

use lib 't/lib';

### Primary key with multiple columns

# table
is(MultiPrimary->schema->table, 'multi_primaries');

# columns
is_deeply([MultiPrimary->schema->columns], [qw/foo bar other/]);

# get primary key
is_deeply([MultiPrimary->schema->primary_key], [qw/foo bar/]);

# is primary key
is(MultiPrimary->schema->is_primary_key(qw/foo bar/), 1);

# is primary key
is(MultiPrimary->schema->is_primary_key(qw/bar foo/), 1);

# missing value
is(MultiPrimary->schema->is_primary_key('foo'), 0);

# to many values
is(MultiPrimary->schema->is_primary_key(qw/foo bar other/), 0);

# wrong values
is(MultiPrimary->schema->is_primary_key(qw/foo other/), 0);


### Multiple unique keys with multiple columns

# get unique_keys
is_deeply(MultiUnique->schema->unique_keys,
    [[qw/first_name last_name/], [qw/city street/]]);

# columns
is_deeply([MultiUnique->schema->columns],
    [qw/id first_name last_name age city street/]);

# is unique key
is(MultiUnique->schema->is_unique_key(qw/first_name last_name/), 1);

# is unique key
is(MultiUnique->schema->is_unique_key(qw/city street/), 1);

# is unique key
is(MultiUnique->schema->is_unique_key(qw/street city/), 1);

# missing value
is(MultiUnique->schema->is_unique_key('first_name'), 0);

# too many values
is(MultiUnique->schema->is_unique_key(qw/first_name last_name city/), 0);

# wrong values
is(MultiUnique->schema->is_unique_key(qw/first_name city/), 0);

# primary key value
is(MultiUnique->schema->is_unique_key(qw/id/), 0);
