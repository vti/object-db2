#!/usr/bin/env perl

package MultiPrimary;
use base 'ObjectDB';
__PACKAGE__->schema->columns(qw/foo bar other/)->primary_key(qw/foo bar/);

package MultiUnique;
use base 'ObjectDB';
__PACKAGE__->schema->columns(qw/id first_name last_name age city street/)
  ->primary_key(qw/id/)
  ->unique_keys([qw/first_name last_name/], [qw/city street/]);


package main;

use strict;
use warnings;

use Test::More tests => 37;

use lib 't/lib';

use TestEnv;

TestEnv->setup;

my $conn = TestDB->conn;



### Primary key with multiple columns

# table
is(MultiPrimary->schema->table, 'multi_primaries');

# columns
is_deeply([MultiPrimary->schema->columns], [qw/foo bar other/]);

# get primary key
is_deeply([MultiPrimary->schema->primary_key], [qw/foo bar/]);

# ... now method _primary_key_columns

# no values
my $multi_primary = MultiPrimary->new;
is($multi_primary->_primary_key_columns, undef);

# primary key
$multi_primary = MultiPrimary->new->column(foo => '', bar => '');
is_deeply([$multi_primary->_primary_key_columns], [qw/foo bar/]);

# primary key
$multi_primary = MultiPrimary->new->column(bar => '', foo => '');
is_deeply([$multi_primary->_primary_key_columns], [qw/foo bar/]);

# missing value
$multi_primary = MultiPrimary->new->column(foo => '');
is($multi_primary->_primary_key_columns, undef);

# NULL/undef NOT allowed
$multi_primary = MultiPrimary->new->column(foo => '', bar => undef);
is($multi_primary->_primary_key_columns, undef);

# too many values, still primary key
$multi_primary = MultiPrimary->new->column(
    foo   => '',
    bar   => '',
    other => ''
);
is_deeply([$multi_primary->_primary_key_columns], [qw/foo bar/]);

# wrong values
$multi_primary = MultiPrimary->new->column(foo => '', other => '');
is($multi_primary->_primary_key_columns, undef);

# ... now method is_primary_key

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

# ... now method _unique_key_columns

# no values
my $multi_unique = MultiUnique->new;
is($multi_unique->_unique_key_columns, undef);

# unique key
$multi_unique = MultiUnique->new->column(first_name => '', last_name => '');
is_deeply([$multi_unique->_unique_key_columns], [qw/first_name last_name/]);

# unique key
$multi_unique = MultiUnique->new->column(city => '', street => '');
is_deeply([$multi_unique->_unique_key_columns], [qw/city street/]);

# unique key
$multi_unique = MultiUnique->new->column(street => '', city => '');
is_deeply([$multi_unique->_unique_key_columns], [qw/city street/]);

# missing value
$multi_unique = MultiUnique->new->column(first_name => '');
is($multi_unique->_unique_key_columns, undef);

# NULL/undef allowed
$multi_unique =
  MultiUnique->new->column(first_name => '', last_name => undef);
is_deeply([$multi_unique->_unique_key_columns], [qw/first_name last_name/]);

# too many values, still unique key
$multi_unique = MultiUnique->new->column(
    first_name => '',
    last_name  => '',
    city       => ''
);
is_deeply([$multi_unique->_unique_key_columns], [qw/first_name last_name/]);

# wrong values
$multi_unique = MultiUnique->new->column(first_name => '', city => '');
is($multi_unique->_unique_key_columns, undef);

# primary key value
$multi_unique = MultiUnique->new->column(id => '');
is($multi_unique->_unique_key_columns, undef);

# ... now method is_unique_key

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


### Method _primary_or_unique_key_columns

# return 0
$multi_unique = MultiUnique->new;
is($multi_unique->_primary_or_unique_key_columns, 0);

# return primary key
$multi_unique = MultiUnique->new->column(id => '');
is_deeply([$multi_unique->_primary_or_unique_key_columns], [qw/id/]);

# return primary key
$multi_unique =
  MultiUnique->new->column(id => '', first_name => '', last_name => '');
is_deeply([$multi_unique->_primary_or_unique_key_columns], [qw/id/]);

# return unique key
$multi_unique = MultiUnique->new->column(first_name => '', last_name => '');
is_deeply([$multi_unique->_primary_or_unique_key_columns],
    [qw/first_name last_name/]);


TestEnv->teardown;
