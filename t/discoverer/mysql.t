#!/usr/bin/env perl

package Foo;
use base 'ObjectDB';
__PACKAGE__->schema('foo');

package main;

use strict;
use warnings;

use Test::More;

use lib 't/lib';

use TestDB;

plan skip_all => 'set TEST_MYSQL to "db,user,pass" to enable this test'
  unless $ENV{TEST_MYSQL};

plan tests => 7;

use_ok('ObjectDB::SchemaDiscoverer::mysql');

my $d =
  ObjectDB::SchemaDiscoverer->build(driver => 'mysql', table => 'authors');

isa_ok($d, 'ObjectDB::SchemaDiscoverer::mysql');

my $conn = TestDB->conn;

$conn->run(sub { $d->discover(shift); });

is($d->table,          'authors');
is($d->auto_increment, 'id');
is_deeply($d->columns,      [qw/id name password/]);
is_deeply($d->primary_keys, [qw/id/]);
is_deeply($d->unique_keys,  [qw/name/]);
