#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 31;

use lib 't/lib';

use TestEnv;
use Author;
use HotelData;

TestEnv->setup;

### Create ObjectDB::TestData::Hotel and test the created objects
# what makes these tests special?
# - mapping columns do not follow naming conventions
# - mapping columns are not primary key columns
# - multiple columns used to map tables

my ($hotel, $hotel2, $hotel3) = HotelData->populate;

is(@{$hotel->apartments},                              2);
is($hotel->apartments->[0]->column('apartment_num_b'), 47);
is($hotel->apartments->[0]->column('name'),            'John F. Kennedy');
is($hotel->apartments->[0]->column('size'),            78);

is($hotel->apartments->[1]->column('apartment_num_b'), 61);
is($hotel->apartments->[1]->column('name'),            'George Washington');
is($hotel->apartments->[1]->column('size'),            50);

is(@{$hotel->apartments->[0]->rooms},                         2);
is($hotel->apartments->[0]->rooms->[0]->column('room_num_c'), 1);
is($hotel->apartments->[0]->rooms->[0]->column('size'),       70);
is($hotel->apartments->[0]->rooms->[1]->column('room_num_c'), 2);
is($hotel->apartments->[0]->rooms->[1]->column('size'),       8);

is(@{$hotel->apartments->[1]->rooms},                         3);
is($hotel->apartments->[1]->rooms->[0]->column('room_num_c'), 1);
is($hotel->apartments->[1]->rooms->[0]->column('size'),       10);
is($hotel->apartments->[1]->rooms->[1]->column('room_num_c'), 2);
is($hotel->apartments->[1]->rooms->[1]->column('size'),       16);
is($hotel->apartments->[1]->rooms->[2]->column('room_num_c'), 3);
is($hotel->apartments->[1]->rooms->[2]->column('size'),       70);

# Now the most interesting part:
is($hotel->apartments->[0]->column('hotel_num_b'), 5);
is($hotel->apartments->[1]->column('hotel_num_b'), 5);

is($hotel->apartments->[0]->rooms->[0]->column('hotel_num_c'),     5);
is($hotel->apartments->[0]->rooms->[1]->column('hotel_num_c'),     5);
is($hotel->apartments->[0]->rooms->[0]->column('apartment_num_c'), 47);
is($hotel->apartments->[0]->rooms->[1]->column('apartment_num_c'), 47);

is($hotel->apartments->[1]->rooms->[0]->column('hotel_num_c'),     5);
is($hotel->apartments->[1]->rooms->[1]->column('hotel_num_c'),     5);
is($hotel->apartments->[1]->rooms->[2]->column('hotel_num_c'),     5);
is($hotel->apartments->[1]->rooms->[0]->column('apartment_num_c'), 61);
is($hotel->apartments->[1]->rooms->[1]->column('apartment_num_c'), 61);
is($hotel->apartments->[1]->rooms->[2]->column('apartment_num_c'), 61);

HotelData->cleanup;

TestEnv->teardown;
