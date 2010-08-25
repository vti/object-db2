#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;

use_ok('ObjectDB::SQL::Where');

my $where;

$where = ObjectDB::SQL::Where->new;
is("$where", "");

$where = ObjectDB::SQL::Where->new;
$where->cond([id => 2, title => 'hello']);
is("$where", " WHERE (`id` = ? AND `title` = ?)");
is_deeply($where->bind, [qw/ 2 hello /]);
is("$where", " WHERE (`id` = ? AND `title` = ?)");
is_deeply($where->bind, [qw/ 2 hello /], 'no side effect');
