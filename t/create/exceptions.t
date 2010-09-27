#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;

use lib 't/lib';


use TestEnv;
TestEnv->setup;

use ParkingLot;

# SQLite allow duplicate primary key entries if primary key col is NULL
# so primary key should be checked on the ORM level
ok( !eval{ ParkingLot->create(number_of_spots=>40) });
my $err_msg = '->create: primary key column can NOT be NULL or has to be AUTOINCREMENT, table: parking_lots';
ok($@ =~ m/\Q$err_msg/, "throw exception: $err_msg");
TestEnv->teardown;

ok( !eval{ ParkingLot->create(
        lot_id_1_l      => undef,
        lot_id_2_l      => 2,
        number_of_spots => 40) });
$err_msg = '->create: primary key column can NOT be NULL or has to be AUTOINCREMENT, table: parking_lots';
ok($@ =~ m/\Q$err_msg/, "throw exception: $err_msg");
TestEnv->teardown;
