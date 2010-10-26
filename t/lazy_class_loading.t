#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 19;

use lib 't/lib';


use TestEnv;
TestEnv->setup;


# Set lazy object loading for CGI environmens
$ENV{OBJECTDB_LAZY} = 1;

use Hotel;

# make sure that only one schema class is loaded at this time
Hotel->find;
is($ENV{OBJECTDB_BUILT_SCHEMAS}, 1);


# "create" hotel, only Hotel class should be loaded
my $hotel = Hotel->create(
        name        => 'President',
        city        => 'New York',
        hotel_num_a => 5
);
my @hotels = Hotel->find( where=>[name=>'President'] );
is($ENV{OBJECTDB_BUILT_SCHEMAS}, 1);
is($hotels[0]->column('city'), 'New York');


# Now check if lazy loading works (NO exception thrown, even if Manager class
# is not loaded so far)
# also make sure that alias for related data (manager) exists
is($hotels[0]->manager, undef);
is($ENV{OBJECTDB_BUILT_SCHEMAS}, 2);


# "create_related" manager data via create_related, still two classes loaded
$hotels[0]->create_related('manager', {manager_num_b => 5555555, name => 'Lalolu'});
my @managers = Manager->find();
is($ENV{OBJECTDB_BUILT_SCHEMAS}, 2);
is($managers[0]->column('hotel_num_b'), $hotels[0]->column('hotel_num_a'));


# "create_related" data via class that hasnt been loaded so far
$managers[0]->create_related('telefon_numbers',[ {tel_num_c => 1111, telefon_number => '123456789'} ]);
is($ENV{OBJECTDB_BUILT_SCHEMAS}, 3);
my @tel_nums = TelefonNumber->find;
is($tel_nums[0]->column('manager_num_c'), $managers[0]->column('manager_num_b'));


# "delete_related", (NO exception thrown, even if Secretary class
# is not loaded so far)
ok( eval{ $managers[0]->delete_related('secretaries')}, 'delete_related: no exception thrown' );
is($ENV{OBJECTDB_BUILT_SCHEMAS}, 4);


# "related", similar to "lazy loading" test above
is( $managers[0]->related('office'), undef);
is($ENV{OBJECTDB_BUILT_SCHEMAS}, 5);


# "delete", one class still not loaded (Car)
$managers[0]->delete;
is($ENV{OBJECTDB_BUILT_SCHEMAS}, 6);


# "find_related"
my @parking_lot = $hotels[0]->find_related('parking_lot');
is(@parking_lot, 0);
is($ENV{OBJECTDB_BUILT_SCHEMAS}, 7);


# "delete"
use Tag;
Tag->new(id=>1)->delete;
is($ENV{OBJECTDB_BUILT_SCHEMAS}, 11);


# _resolve_where
@hotels = Hotel->find(where=>['apartments.size' => 4]);
is($ENV{OBJECTDB_BUILT_SCHEMAS}, 12);


# prefetch
my @apartments = Apartment->find(with => 'rooms');
is($ENV{OBJECTDB_BUILT_SCHEMAS}, 13);


# TO DO: max/min n per group

$ENV{OBJECTDB_LAZY} = 0;

TestEnv->teardown;
