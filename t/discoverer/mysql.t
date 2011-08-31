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

plan tests => 11;

use_ok('ObjectDB::SchemaDiscoverer::mysql');

my $d =
  ObjectDB::SchemaDiscoverer->build(driver => 'mysql', table => 'authors');

isa_ok($d, 'ObjectDB::SchemaDiscoverer::mysql');

my $dbh = TestDB->dbh;

$d->discover($dbh);

is($d->table,          'authors');
is($d->auto_increment, 'id');
is_deeply($d->columns,          [qw/id name password/]);
is_deeply($d->primary_key,      [qw/id/]);
is_deeply($d->unique_keys->[0], [qw/name/]);


# Throw an exeption if table does not exist
$d = ObjectDB::SchemaDiscoverer->build(driver => 'mysql', table => 'h');
ok(!eval { $d->discover($dbh) });
my $err_msg = 'SchemaDiscoverer::mysql: table h not found in DB';
ok($@ =~ m/\Q$err_msg/, "throw exception: $err_msg");


# Multiple unique keys with multiple columns
$d = ObjectDB::SchemaDiscoverer->build(
    driver => 'mysql',
    table  => 'hotels'
);
$d->discover($dbh);
is_deeply($d->unique_keys->[0], [qw/city street/]);
is_deeply($d->unique_keys->[1], [qw/name city/]);
