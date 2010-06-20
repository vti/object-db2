#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;

use_ok('ObjectDB::SQL::Insert');

my $sql = ObjectDB::SQL::Insert->new;

$sql->table('foo');
is("$sql", "INSERT INTO `foo` DEFAULT VALUES");

$sql->table('foo');
$sql->columns([qw/a b c/]);
is("$sql", "INSERT INTO `foo` (`a`, `b`, `c`) VALUES (?, ?, ?)");

$sql = ObjectDB::SQL::Insert->new;
$sql->table('bar');
$sql->columns([qw/bo boo booo/]);
is("$sql", "INSERT INTO `bar` (`bo`, `boo`, `booo`) VALUES (?, ?, ?)");
