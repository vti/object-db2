#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 31;

use lib 't/lib';

use TestEnv;
use Author;
use HotelData;

TestEnv->setup;

### Populate HotelData and test the created objects
# what makes these tests special?
# - mapping columns do not follow naming conventions
# - mapping columns are not primary key columns
# - multiple columns used to map tables

my ($hotel, $hotel2, $hotel3) = HotelData->populate;

is(@{$hotel->apartments},                              2);
is($hotel->apartments->[0]->apartment_num_b, 47);
is($hotel->apartments->[0]->name,            'John F. Kennedy');
is($hotel->apartments->[0]->size,            78);

is($hotel->apartments->[1]->apartment_num_b, 61);
is($hotel->apartments->[1]->name,            'George Washington');
is($hotel->apartments->[1]->size,            50);

is(@{$hotel->apartments->[0]->rooms},                         2);
is($hotel->apartments->[0]->rooms->[0]->room_num_c, 1);
is($hotel->apartments->[0]->rooms->[0]->size,       70);
is($hotel->apartments->[0]->rooms->[1]->room_num_c, 2);
is($hotel->apartments->[0]->rooms->[1]->size,       8);

is(@{$hotel->apartments->[1]->rooms},                         3);
is($hotel->apartments->[1]->rooms->[0]->room_num_c, 1);
is($hotel->apartments->[1]->rooms->[0]->size,       10);
is($hotel->apartments->[1]->rooms->[1]->room_num_c, 2);
is($hotel->apartments->[1]->rooms->[1]->size,       16);
is($hotel->apartments->[1]->rooms->[2]->room_num_c, 3);
is($hotel->apartments->[1]->rooms->[2]->size,       70);

# Now the most interesting part:
is($hotel->apartments->[0]->hotel_num_b, 5);
is($hotel->apartments->[1]->hotel_num_b, 5);

is($hotel->apartments->[0]->rooms->[0]->hotel_num_c,     5);
is($hotel->apartments->[0]->rooms->[1]->hotel_num_c,     5);
is($hotel->apartments->[0]->rooms->[0]->apartment_num_c, 47);
is($hotel->apartments->[0]->rooms->[1]->apartment_num_c, 47);

is($hotel->apartments->[1]->rooms->[0]->hotel_num_c,     5);
is($hotel->apartments->[1]->rooms->[1]->hotel_num_c,     5);
is($hotel->apartments->[1]->rooms->[2]->hotel_num_c,     5);
is($hotel->apartments->[1]->rooms->[0]->apartment_num_c, 61);
is($hotel->apartments->[1]->rooms->[1]->apartment_num_c, 61);
is($hotel->apartments->[1]->rooms->[2]->apartment_num_c, 61);

HotelData->cleanup;

TestEnv->teardown;
