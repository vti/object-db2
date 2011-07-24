#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

plan skip_all => 'TEST_MYSQL disables this test' if $ENV{TEST_MYSQL};

plan tests => 15;

use lib 't/lib';

use TestDB;
use TestEnv;

use_ok('ObjectDB::SchemaDiscoverer');

TestEnv->setup;

my $dbh = TestDB->conn->dbh;

my $d;

$d =
  ObjectDB::SchemaDiscoverer->build(driver => 'SQLite', table => 'authors');
ok($d);

$d->discover($dbh);

is($d->table,          'authors');
is($d->auto_increment, 'id');
is_deeply($d->columns,          [qw/id name password/]);
is_deeply($d->primary_key,      [qw/id/]);
is_deeply($d->unique_keys->[0], [qw/name/]);

$d = ObjectDB::SchemaDiscoverer->build(
    driver => 'SQLite',
    table  => 'article_tag_maps'
);
ok($d);

$d->discover($dbh);

is($d->table, 'article_tag_maps');
is_deeply($d->columns,     [qw/article_id tag_id/]);
is_deeply($d->primary_key, [qw/article_id tag_id/]);


# Throw an exeption if table does not exist
$d = ObjectDB::SchemaDiscoverer->build(driver => 'SQLite', table => 'h');
ok(!eval { $d->discover($dbh) });
my $err_msg = "SchemaDiscoverer::SQLite: table 'h' not found in DB";
ok($@ =~ m/\Q$err_msg/, "throw exception: $err_msg");


# Multiple unique keys with multiple columns, passed to SQLite in format:
# UNIQUE(`col1`,`col2`)
$d = ObjectDB::SchemaDiscoverer->build(
    driver => 'SQLite',
    table => 'hotels');
$d->discover($dbh);
is_deeply($d->unique_keys->[0], [qw/city street/]);
is_deeply($d->unique_keys->[1], [qw/name city/]);

TestEnv->teardown;
