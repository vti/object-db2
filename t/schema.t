#!/usr/bin/env perl

package Dummy;
use base 'ObjectDB';

package main;

use strict;
use warnings;

use Test::More tests => 18;

use lib 't/lib';

use TestDB;

use_ok('ObjectDB::Schema');

my $conn = TestDB->conn;

my $schema = ObjectDB::Schema->new(class => 'Author');
$schema->build($conn);
$schema->has_one('foo');
$schema->belongs_to('bar');

is($schema->class, 'Author');
is($schema->table, 'authors');
is($schema->auto_increment, 'id');
is_deeply($schema->columns, [qw/id name password/]);
is_deeply($schema->primary_keys, [qw/id/]);
is_deeply($schema->unique_keys, [qw/name/]);

ok($schema->is_primary_key('id'));
ok(!$schema->is_primary_key('foo'));
ok($schema->is_unique_key('name'));
ok(!$schema->is_unique_key('foo'));
ok($schema->is_column('id'));
ok(!$schema->is_column('foo'));

is_deeply([$schema->child_relationships], [qw/foo/]);
is_deeply([$schema->parent_relationships], [qw/bar/]);

Dummy->schema->build($conn);
is(Dummy->schema->class, 'Dummy');
is(Dummy->schema->table, 'dummies');
is(Dummy->schema->auto_increment, 'id');
