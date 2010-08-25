#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;

use_ok('ObjectDB::SQL::Base');

my $sql = ObjectDB::SQL::Base->new;

is_deeply($sql->where, '');
is_deeply($sql->bind, []);
