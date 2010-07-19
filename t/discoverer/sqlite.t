#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 7;

use File::Temp;
use DBI;

use_ok('ObjectDB::SchemaDiscoverer');

my $d =
  ObjectDB::SchemaDiscoverer->build(driver => 'SQLite', table => 'authors');

ok($d);

my $dbh = DBI->connect('dbi:SQLite:/tmp/object-db-test.db');

$d->discover($dbh);

is($d->table,          'authors');
is($d->auto_increment, 'id');
is_deeply($d->columns,      [qw/id name password/]);
is_deeply($d->primary_keys, [qw/id/]);
is_deeply($d->unique_keys,  [qw/name/]);
