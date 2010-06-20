#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;

use_ok('ObjectDB::SQL::Delete');

my $sql = ObjectDB::SQL::Delete->new;

$sql->table('foo');
is("$sql", "DELETE FROM `foo`");

$sql = ObjectDB::SQL::Delete->new;
$sql->table('foo');
$sql->where([id => 2]);
is("$sql", "DELETE FROM `foo` WHERE (`id` = ?)");
is_deeply($sql->bind, [2]);
