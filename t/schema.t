#!/usr/bin/env perl

package Dummy;
use base 'ObjectDB';

package Dummy::Deeper;
use base 'ObjectDB';
__PACKAGE__->schema->columns(qw/id foo/)->primary_key('id');

package DummyParent;
use base 'ObjectDB';
__PACKAGE__->schema('passed_a_table_name');
__PACKAGE__->schema->columns(qw/id foo/)->primary_key('id');
__PACKAGE__->schema->has_many('dummy_childs');

package DummyChild;
use base 'ObjectDB';
__PACKAGE__->schema->columns(qw/id foo/)->primary_key('id');

# Pass short class name "Friend", which refers to "Best::Friend" as namespace
# is defined in sub namespace {} (usually in subclass of ObjectDB)
__PACKAGE__->schema->has_one('best_friend', foreign_class => 'Friend');
sub namespace {'Best'}

package DummyChild2;
use base 'ObjectDB';
__PACKAGE__->schema->columns(qw/id foo/)->primary_key('id');

# Define namespace just for a specific class (before defining any rel.!)
__PACKAGE__->schema->namespace('Best');
__PACKAGE__->schema->has_one('best_friend', foreign_class => 'Friend');

package DummyWithTable;
use base 'ObjectDB';
__PACKAGE__->schema('foo')->columns(qw/foo bar/)->primary_key(qw/foo bar/);

package MultiPrimary;
use base 'ObjectDB';
__PACKAGE__->schema->columns(qw/foo bar other/)->primary_key(qw/foo bar/);

package Dummy::InNamespace;
use base 'ObjectDB';
__PACKAGE__->namespace('Dummy');
__PACKAGE__->schema->columns(qw/id foo/)->primary_key('id');

package Dummy::InNamespace::Item;
use base 'ObjectDB';
__PACKAGE__->schema('in_namespace-items');
__PACKAGE__->namespace('Dummy::InNamespace');
__PACKAGE__->schema->columns(qw/id foo/)->primary_key('id');

package Best::Friend;
use base 'ObjectDB';
__PACKAGE__->schema->columns(qw/id foo/)->primary_key('id');

package BigMan;
use base 'ObjectDB';
__PACKAGE__->schema->columns(qw/id foo/)->primary_key('id');

sub plural_class_name {'BigMen'}

package MultiUnique;
use base 'ObjectDB';
__PACKAGE__->schema->columns(qw/id first_name last_name age city street/)
  ->primary_key(qw/id/)
  ->unique_keys([qw/first_name last_name/], [qw/city street/]);


package main;

use strict;
use warnings;

use Test::More tests => 78;

use lib 't/lib';

use TestEnv;

use_ok('ObjectDB::Schema');

TestEnv->setup;

my $conn = TestDB->conn;

my $schema = ObjectDB::Schema->new(class => 'Author');
$schema->build(TestDB->init_conn);
$schema->has_one('foo');
$schema->belongs_to('bar');

is($schema->class,          'Author');
is($schema->table,          'authors');
is($schema->auto_increment, 'id');
is_deeply([$schema->columns],         [qw/id name password/]);
is_deeply([$schema->primary_key],     [qw/id/]);
is_deeply($schema->unique_keys->[0],  [qw/name/]);
is_deeply([$schema->regular_columns], [qw/name password/]);

ok($schema->is_primary_key('id'));
ok($schema->is_in_primary_key('id'));
ok(!$schema->is_primary_key('foo'));
ok(!$schema->is_in_primary_key('foo'));
ok($schema->is_unique_key('name'));
ok(!$schema->is_unique_key('foo'));
ok($schema->is_column('id'));
ok(!$schema->is_column('foo'));

is_deeply([$schema->child_relationships],  [qw/foo/]);
is_deeply([$schema->parent_relationships], [qw/bar/]);

my $result = $schema->has_one('foo');

isa_ok($result, ref($schema));
is($result, $schema);
is_deeply([$schema->child_relationships], [qw/foo/]);

$result = $schema->has_one(['xyz', 'yzx', 'zyx']);
is_deeply([sort $schema->child_relationships], [sort qw/foo xyz yzx zyx/]);

Dummy->schema->build(TestDB->init_conn);
is(Dummy->schema->class,          'Dummy');
is(Dummy->schema->table,          'dummies');
is(Dummy->schema->auto_increment, 'id');

Dummy::Deeper->schema->build(TestDB->init_conn);
is(Dummy::Deeper->schema->class, 'Dummy::Deeper');
is(Dummy::Deeper->schema->table, 'deepers');

DummyParent->schema->build(TestDB->init_conn);
is(DummyParent->schema->class, 'DummyParent');
is(DummyParent->schema->table, 'passed_a_table_name');
is(DummyParent->schema->relationship('dummy_childs')->table,
    'passed_a_table_name');

DummyChild->schema->build(TestDB->init_conn);
is(DummyChild->schema->relationship('best_friend')->build(TestDB->init_conn)->foreign_class,
    'Best::Friend');

DummyChild2->schema->build(TestDB->init_conn);
is(DummyChild2->schema->relationship('best_friend')->build(TestDB->init_conn)->foreign_class,
    'Best::Friend');

DummyWithTable->schema->build(TestDB->init_conn);
is(DummyWithTable->schema->table, 'foo');
is_deeply([DummyWithTable->schema->primary_key], [qw/foo bar/]);
is_deeply([DummyWithTable->schema->columns],     [qw/foo bar/]);


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


Dummy::InNamespace->schema->build(TestDB->init_conn);
is(Dummy::InNamespace->schema->class, 'Dummy::InNamespace');
is(Dummy::InNamespace->schema->table, 'in_namespaces');

Dummy::InNamespace::Item->schema->build(TestDB->init_conn);
is(Dummy::InNamespace::Item->schema->class, 'Dummy::InNamespace::Item');
is(Dummy::InNamespace::Item->schema->table, 'in_namespace-items');

BigMan->schema->build(TestDB->init_conn);
is(BigMan->schema->class, 'BigMan');
is(BigMan->schema->table, 'big_men');


TestEnv->teardown;
