#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;

use lib 't/lib';


use TestEnv;
TestEnv->setup;

use ParkingLot;

# SQLite allow duplicate primary key entries if primary key col is NULL
# so primary key should be checked on the ORM level
ok( !eval{ ParkingLot->create(number_of_spots=>40) });
my $err_msg = '->create: primary key column can NOT be NULL or has to be AUTO INCREMENT, table: parking_lots';
ok($@ =~ m/\Q$err_msg/, "throw exception: $err_msg");
TestEnv->teardown;
