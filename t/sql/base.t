#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;

use_ok('ObjectDB::SQL::Base');

my $sql = ObjectDB::SQL::Base->new;

is($sql->escape('foo'), '`foo`');
is($sql->escape('fo`o'), '`fo\`o`');
