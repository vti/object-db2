#!/usr/bin/env perl

package Dummy;
use base 'ObjectDB';

package Dummy::Deeper;
use base 'ObjectDB';

package DummyParent;
use base 'ObjectDB';
__PACKAGE__->schema('passed_a_table_name');
__PACKAGE__->schema->has_many('dummy_childs');

package DummyChild;
use base 'ObjectDB';

# Pass short class name "Friend", which refers to "Best::Friend" as namespace
# is defined in sub namespace {} (usually in subclass of ObjectDB)
__PACKAGE__->schema->has_one('best_friend', foreign_class => 'Friend');
sub namespace {'Best'}

package DummyChild2;
use base 'ObjectDB';

# Define namespace just for a specific class (before defining any rel.!)
__PACKAGE__->schema->namespace('Best');
__PACKAGE__->schema->has_one('best_friend', foreign_class => 'Friend');

package Dummy::InNamespace;
use base 'ObjectDB';
__PACKAGE__->namespace('Dummy');

package Dummy::InNamespace::Item;
use base 'ObjectDB';
__PACKAGE__->schema('in_namespace-items');
__PACKAGE__->namespace('Dummy::InNamespace');

package Best::Friend;
use base 'ObjectDB';


package main;

use strict;
use warnings;

use Test::More tests => 33;

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
is_deeply($schema->columns,      [qw/id name password/]);
is_deeply($schema->primary_keys, [qw/id/]);
is_deeply($schema->unique_keys,  [qw/name/]);

ok($schema->is_primary_key('id'));
ok(!$schema->is_primary_key('foo'));
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

Dummy::InNamespace->schema->build(TestDB->init_conn);
is(Dummy::InNamespace->schema->class, 'Dummy::InNamespace');
is(Dummy::InNamespace->schema->table, 'in_namespaces');

Dummy::InNamespace::Item->schema->build(TestDB->init_conn);
is(Dummy::InNamespace::Item->schema->class, 'Dummy::InNamespace::Item');
is(Dummy::InNamespace::Item->schema->table, 'in_namespace-items');


TestEnv->teardown;
