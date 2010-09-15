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

package DummyWithMultiPrimaryKey;
use base 'ObjectDB';
__PACKAGE__->schema->columns(qw/foo bar/)->primary_key(qw/foo bar/);

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

package DummyWithMultiUniqueKey;
use base 'ObjectDB';
__PACKAGE__->schema->columns(qw/id first_name last_name age city street/)
  ->primary_key(qw/id/)
  ->unique_keys([qw/first_name last_name/], [qw/city street/]);


package main;

use strict;
use warnings;

use Test::More tests => 66;

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
is(DummyChild->schema->relationship('best_friend')->foreign_class,
    'Best::Friend');

DummyChild2->schema->build(TestDB->init_conn);
is(DummyChild2->schema->relationship('best_friend')->foreign_class,
    'Best::Friend');

DummyWithTable->schema->build(TestDB->init_conn);
is(DummyWithTable->schema->table, 'foo');
is_deeply([DummyWithTable->schema->primary_key], [qw/foo bar/]);
is_deeply([DummyWithTable->schema->columns],     [qw/foo bar/]);

DummyWithMultiPrimaryKey->schema->build(TestDB->init_conn);
is(DummyWithMultiPrimaryKey->schema->table, 'dummy_with_multi_primary_keys');
is_deeply([DummyWithMultiPrimaryKey->schema->primary_key], [qw/foo bar/]);
ok(!DummyWithMultiPrimaryKey->schema->is_primary_key('foo'));
ok(DummyWithMultiPrimaryKey->schema->is_primary_key(qw/foo bar/));
ok(DummyWithMultiPrimaryKey->schema->is_primary_key(qw/bar foo/));
is_deeply([DummyWithMultiPrimaryKey->schema->columns], [qw/foo bar/]);


### Multiple unique keys with multiple columns

# unique_keys
is_deeply(
    DummyWithMultiUniqueKey->schema->unique_keys,
    [[qw/first_name last_name/], [qw/city street/]]
);

# columns
is_deeply(
    [DummyWithMultiUniqueKey->schema->columns],
    [qw/id first_name last_name age city street/]
);

# ... now method _unique_key_columns

# no values
my $muli_unique_keys = DummyWithMultiUniqueKey->new;
is($muli_unique_keys->_unique_key_columns, undef);

# unique key
$muli_unique_keys =
  DummyWithMultiUniqueKey->new->column(first_name => '', last_name => '');
is_deeply([$muli_unique_keys->_unique_key_columns],
    [qw/first_name last_name/]);

# unique key
$muli_unique_keys =
  DummyWithMultiUniqueKey->new->column(city => '', street => '');
is_deeply([$muli_unique_keys->_unique_key_columns], [qw/city street/]);

# unique key
$muli_unique_keys =
  DummyWithMultiUniqueKey->new->column(street => '', city => '');
is_deeply([$muli_unique_keys->_unique_key_columns], [qw/city street/]);

# missing value
$muli_unique_keys = DummyWithMultiUniqueKey->new->column(first_name => '');
is($muli_unique_keys->_unique_key_columns, undef);

# NULL/undef allowed
$muli_unique_keys =
  DummyWithMultiUniqueKey->new->column(first_name => '', last_name => undef);
is_deeply([$muli_unique_keys->_unique_key_columns],
    [qw/first_name last_name/]);

# too many values, still unique key
$muli_unique_keys = DummyWithMultiUniqueKey->new->column(
    first_name => '',
    last_name  => '',
    city       => ''
);
is_deeply([$muli_unique_keys->_unique_key_columns],
    [qw/first_name last_name/]);

# wrong values
$muli_unique_keys =
  DummyWithMultiUniqueKey->new->column(first_name => '', city => '');
is($muli_unique_keys->_unique_key_columns, undef);

# primary key value
$muli_unique_keys = DummyWithMultiUniqueKey->new->column(id => '');
is($muli_unique_keys->_unique_key_columns, undef);

# ... now method is_unique_key

# no values
is(DummyWithMultiUniqueKey->schema->is_unique_key('first_name'), 0);

# is unique key
is(DummyWithMultiUniqueKey->schema->is_unique_key(qw/first_name last_name/),
    1);

# is unique key
is(DummyWithMultiUniqueKey->schema->is_unique_key(qw/city street/), 1);

# is unique key
is(DummyWithMultiUniqueKey->schema->is_unique_key(qw/street city/), 1);

# missing value
is(DummyWithMultiUniqueKey->schema->is_unique_key('first_name'), 0);

# too many values
is( DummyWithMultiUniqueKey->schema->is_unique_key(
        qw/first_name last_name city/),
    0
);

# wrong values
is(DummyWithMultiUniqueKey->schema->is_unique_key(qw/first_name city/), 0);

# primary key value
is(DummyWithMultiUniqueKey->schema->is_unique_key(qw/id/), 0);


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
