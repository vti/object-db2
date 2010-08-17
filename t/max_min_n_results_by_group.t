#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 213;

use lib 't/lib';

use DBI;
use TestDB;

my $conn = TestDB->conn;

### ObjectDB::TestData::Hotel

require "t/test_data/hotel.testdata";
ObjectDB::TestData::Hotel->load($conn);



# strict max: find the biggest room of each hotel
# (or in case of same size, the room with the lower id)

my @rooms =
  Room->find( conn=>$conn,
    max => { column => 'size', group => 'hotel_num_c' }
  );
is( @rooms, 3);
is( $rooms[0]->column('hotel_num_c'), 5 );
is( $rooms[0]->column('apartment_num_c'), 47 );
is( $rooms[0]->column('room_num_c'), 1 );
is( $rooms[0]->column('size'), 70 );
is( $rooms[1]->column('hotel_num_c'), 6 );
is( $rooms[1]->column('apartment_num_c'), 47 );
is( $rooms[1]->column('room_num_c'), 1 );
is( $rooms[1]->column('size'), 70 );
is( $rooms[2]->column('hotel_num_c'), 7 );
is( $rooms[2]->column('apartment_num_c'), 11 );
is( $rooms[2]->column('room_num_c'), 1 );
is( $rooms[2]->column('size'), 71 );



# same test, but turn strict off
# find the biggest room of each hotel, in case of multiple rooms
# with same size per hotel, find all these rooms
@rooms =
  Room->find( conn=>$conn,
    max => { column => 'size', group => 'hotel_num_c', strict => 0 }
  );
is( @rooms, 4);
is( $rooms[0]->column('hotel_num_c'), 5 );
is( $rooms[0]->column('apartment_num_c'), 47 );
is( $rooms[0]->column('room_num_c'), 1 );
is( $rooms[0]->column('size'), 70 );

is( $rooms[1]->column('hotel_num_c'), 5 );
is( $rooms[1]->column('apartment_num_c'), 61 );
is( $rooms[1]->column('room_num_c'), 3 );
is( $rooms[1]->column('size'), 70 );

is( $rooms[2]->column('hotel_num_c'), 6 );
is( $rooms[2]->column('apartment_num_c'), 47 );
is( $rooms[2]->column('room_num_c'), 1 );
is( $rooms[2]->column('size'), 70 );
is( $rooms[3]->column('hotel_num_c'), 7 );
is( $rooms[3]->column('apartment_num_c'), 11 );
is( $rooms[3]->column('room_num_c'), 1 );
is( $rooms[3]->column('size'), 71 );



# strict min find the smallest room of each hotel
# (or in case of same size, the room with the lower id)
@rooms =
  Room->find( conn=>$conn,
    min => { column => 'size', group => 'hotel_num_c'}
  );
is( @rooms, 3);
is( $rooms[0]->column('hotel_num_c'), 5 );
is( $rooms[0]->column('apartment_num_c'), 47 );
is( $rooms[0]->column('room_num_c'), 2 );
is( $rooms[0]->column('size'), 8 );
is( $rooms[1]->column('hotel_num_c'), 6 );
is( $rooms[1]->column('apartment_num_c'), 47 );
is( $rooms[1]->column('room_num_c'), 2 );
is( $rooms[1]->column('size'), 8 );
is( $rooms[2]->column('hotel_num_c'), 7 );
is( $rooms[2]->column('apartment_num_c'), 11 );
is( $rooms[2]->column('room_num_c'), 2 );
is( $rooms[2]->column('size'), 7 );


# same test, but turn strict off
# find the smallest room of each hotel, in case of multiple rooms
# with same size per hotel, find all these rooms
@rooms =
  Room->find( conn=>$conn,
    min => { column => 'size', group => 'hotel_num_c', strict=>0}
  );
is( @rooms, 5);
is( $rooms[0]->column('hotel_num_c'), 5 );
is( $rooms[0]->column('apartment_num_c'), 47 );
is( $rooms[0]->column('room_num_c'), 2 );
is( $rooms[0]->column('size'), 8 );
is( $rooms[1]->column('hotel_num_c'), 6 );
is( $rooms[1]->column('apartment_num_c'), 47 );
is( $rooms[1]->column('room_num_c'), 2 );
is( $rooms[1]->column('size'), 8 );
is( $rooms[2]->column('hotel_num_c'), 7 );
is( $rooms[2]->column('apartment_num_c'), 11 );
is( $rooms[2]->column('room_num_c'), 2 );
is( $rooms[2]->column('size'), 7 );
is( $rooms[3]->column('hotel_num_c'), 7 );
is( $rooms[3]->column('apartment_num_c'), 12 );
is( $rooms[3]->column('room_num_c'), 4 );
is( $rooms[3]->column('size'), 7 );
is( $rooms[4]->column('hotel_num_c'), 7 );
is( $rooms[4]->column('apartment_num_c'), 12 );
is( $rooms[4]->column('room_num_c'), 5 );
is( $rooms[4]->column('size'), 7 );



# Multiple grouping columns, find smallest room for each apartment
@rooms =
  Room->find( conn=>$conn,
    min => { column => 'size', group => ['hotel_num_c','apartment_num_c'] }
  );
is( @rooms, 6); ### should be 6 ??
is( $rooms[0]->column('size'), 8 );
is( $rooms[1]->column('size'), 10 );
is( $rooms[2]->column('hotel_num_c'), 6 );
is( $rooms[2]->column('apartment_num_c'), 47 );
is( $rooms[2]->column('room_num_c'), 2 );
is( $rooms[2]->column('size'), 8 );
is( $rooms[3]->column('size'), 10 );
is( $rooms[4]->column('size'), 7 );
is( $rooms[5]->column('size'), 7 );



# same test, without strict
@rooms =
  Room->find( conn=>$conn,
    min => { column => 'size', group => ['hotel_num_c','apartment_num_c'], strict=>0 }
  );
is( @rooms, 7); ### should be 6 ??
is( $rooms[0]->column('size'), 8 );
is( $rooms[1]->column('size'), 10 );
is( $rooms[2]->column('size'), 8 );
is( $rooms[3]->column('size'), 10 );
is( $rooms[4]->column('size'), 7 );
is( $rooms[5]->column('size'), 7 );
is( $rooms[6]->column('hotel_num_c'), 7 );
is( $rooms[6]->column('apartment_num_c'), 12 );
is( $rooms[6]->column('room_num_c'), 5 );
is( $rooms[6]->column('size'), 7 );



# strict top 2
# Get the Top 2 rooms per hotel with biggest size
@rooms =
  Room->find( conn=>$conn,
    max => { column => 'size', group => 'hotel_num_c', top=>2 }
  );
is( @rooms, 6);
is( $rooms[0]->column('room_num_c'), 1 );
is( $rooms[0]->column('size'), 70 );
is( $rooms[1]->column('room_num_c'), 3 );
is( $rooms[1]->column('size'), 70 );

is( $rooms[2]->column('room_num_c'), 1 );
is( $rooms[2]->column('size'), 70 );
is( $rooms[3]->column('room_num_c'), 3 );
is( $rooms[3]->column('size'), 25 );

is( $rooms[4]->column('room_num_c'), 1 );
is( $rooms[4]->column('size'), 71 );
is( $rooms[5]->column('room_num_c'), 3 );
is( $rooms[5]->column('size'), 25 );



# same test without strict
@rooms =
  Room->find( conn=>$conn,
    max => { column => 'size', group => 'hotel_num_c', top=>2, strict=>0 }
  );
is( @rooms, 6);
is( $rooms[0]->column('room_num_c'), 1 );
is( $rooms[0]->column('size'), 70 );
is( $rooms[1]->column('room_num_c'), 3 );
is( $rooms[1]->column('size'), 70 );

is( $rooms[2]->column('room_num_c'), 1 );
is( $rooms[2]->column('size'), 70 );
is( $rooms[3]->column('room_num_c'), 3 );
is( $rooms[3]->column('size'), 25 );

is( $rooms[4]->column('room_num_c'), 1 );
is( $rooms[4]->column('size'), 71 );
is( $rooms[5]->column('room_num_c'), 3 );
is( $rooms[5]->column('size'), 25 );



# now the same test with min, and order_by to up the ante
@rooms =
  Room->find( conn=>$conn,
    min => { column => 'size', group => 'hotel_num_c', top=>2 },
    order_by => 'hotel_num_c asc, size asc, room_num_c desc'
  );
is( @rooms, 6);
is( $rooms[0]->column('hotel_num_c'), 5 );
is( $rooms[0]->column('room_num_c'), 2 );
is( $rooms[0]->column('size'), 8 );
is( $rooms[1]->column('hotel_num_c'), 5 );
is( $rooms[1]->column('room_num_c'), 1 );
is( $rooms[1]->column('size'), 10 );

is( $rooms[2]->column('hotel_num_c'), 6 );
is( $rooms[2]->column('room_num_c'), 2 );
is( $rooms[2]->column('size'), 8 );
is( $rooms[3]->column('hotel_num_c'), 6 );
is( $rooms[3]->column('room_num_c'), 1 );
is( $rooms[3]->column('size'), 10 );

is( $rooms[4]->column('hotel_num_c'), 7 );
is( $rooms[4]->column('room_num_c'), 4 ); # second lowest id
is( $rooms[4]->column('size'), 7 );
is( $rooms[5]->column('hotel_num_c'), 7 );
is( $rooms[5]->column('room_num_c'), 2 ); # lowest id
is( $rooms[5]->column('size'), 7 );



# same test, but strict turned off
@rooms =
  Room->find( conn=>$conn,
    min => { column => 'size', group => 'hotel_num_c', top=>2, strict=>0 },
    order_by => 'hotel_num_c asc, size asc, room_num_c desc'
  );

is( @rooms, 7); ## TO DO: SHOULD BE 6 ??? (3 rooms with same size in 3rd hotel)
is( $rooms[0]->column('hotel_num_c'), 5 );
is( $rooms[0]->column('room_num_c'), 2 );
is( $rooms[0]->column('size'), 8 );
is( $rooms[1]->column('hotel_num_c'), 5 );
is( $rooms[1]->column('room_num_c'), 1 );
is( $rooms[1]->column('size'), 10 );

is( $rooms[2]->column('hotel_num_c'), 6 );
is( $rooms[2]->column('room_num_c'), 2 );
is( $rooms[2]->column('size'), 8 );
is( $rooms[3]->column('hotel_num_c'), 6 );
is( $rooms[3]->column('room_num_c'), 1 );
is( $rooms[3]->column('size'), 10 );

is( $rooms[4]->column('hotel_num_c'), 7 );
is( $rooms[4]->column('room_num_c'), 5 );
is( $rooms[4]->column('size'), 7 );
is( $rooms[5]->column('hotel_num_c'), 7 );
is( $rooms[5]->column('room_num_c'), 4 );
is( $rooms[5]->column('size'), 7 );
is( $rooms[6]->column('hotel_num_c'), 7 );
is( $rooms[6]->column('room_num_c'), 2 );
is( $rooms[6]->column('size'), 7 );



###### NESTED IN WITH

# Prefetch only the biggest room of each hotel
my @hotels =
  Hotel->find( conn=>$conn,
    with => [ 'apartments.rooms' => { max=>{column=>'size', group=>'hotel_num_c'} }] );
is( @hotels, 3);
is( @{$hotels[0]->apartments->[0]->rooms}, 1 );
is( $hotels[0]->apartments->[0]->rooms->[0]->column('size'), 70 );
is( @{$hotels[0]->apartments->[1]->rooms}, 0 );
is( @{$hotels[1]->apartments->[0]->rooms}, 1 );
is( $hotels[1]->apartments->[0]->rooms->[0]->column('size'), 70 );
is( @{$hotels[1]->apartments->[1]->rooms}, 0 );
is( @{$hotels[2]->apartments->[0]->rooms}, 1 );
is( $hotels[2]->apartments->[0]->rooms->[0]->column('size'), 71 );
is( @{$hotels[2]->apartments->[1]->rooms}, 0 );



# same test, but now less strict (include all biggest rooms per hotel)
@hotels =
  Hotel->find( conn=>$conn,
    with => [ 'apartments.rooms' => { max=>{column=>'size', group=>'hotel_num_c', strict=>0} }] );
is( @hotels, 3);
is( @{$hotels[0]->apartments->[0]->rooms}, 1 );
is( $hotels[0]->apartments->[0]->rooms->[0]->column('size'), 70 );
is( @{$hotels[0]->apartments->[1]->rooms}, 1 ); ### a second room with same size is loaded
is( $hotels[0]->apartments->[1]->rooms->[0]->column('size'), 70 );
is( @{$hotels[1]->apartments->[0]->rooms}, 1 );
is( $hotels[1]->apartments->[0]->rooms->[0]->column('size'), 70 );
is( @{$hotels[1]->apartments->[1]->rooms}, 0 );
is( @{$hotels[2]->apartments->[0]->rooms}, 1 );
is( $hotels[2]->apartments->[0]->rooms->[0]->column('size'), 71 );
is( @{$hotels[2]->apartments->[1]->rooms}, 0 );




# Prefetch the TWO biggest rooms of each hotel
@hotels =
  Hotel->find( conn=>$conn,
    with => [ 'apartments.rooms' => { max=>{column=>'size', group=>'hotel_num_c', top=>2} }] );
is( @hotels, 3);
is( @{$hotels[0]->apartments->[0]->rooms}, 1 );
is( $hotels[0]->apartments->[0]->rooms->[0]->column('size'), 70 );
is( @{$hotels[0]->apartments->[1]->rooms}, 1 );
is( $hotels[0]->apartments->[1]->rooms->[0]->column('size'), 70 );
is( @{$hotels[1]->apartments->[0]->rooms}, 1 );
is( $hotels[1]->apartments->[0]->rooms->[0]->column('size'), 70 );
is( @{$hotels[1]->apartments->[1]->rooms}, 1 );
is( $hotels[1]->apartments->[1]->rooms->[0]->column('size'), 25 );
is( @{$hotels[2]->apartments->[0]->rooms}, 1 );
is( $hotels[2]->apartments->[0]->rooms->[0]->column('size'), 71 );
is( @{$hotels[2]->apartments->[1]->rooms}, 1 );
is( $hotels[2]->apartments->[1]->rooms->[0]->column('size'), 25 );



# Prefetch only the 2 smalest rooms of each hotel
@hotels =
  Hotel->find( conn=>$conn,
    with => [ 'apartments.rooms' => { min=>{column=>'size', group=>'hotel_num_c', top=>2 } }] );
is( @hotels, 3);
is( @{$hotels[0]->apartments->[0]->rooms}, 1 );
is( $hotels[0]->apartments->[0]->rooms->[0]->column('size'), 8 );
is( @{$hotels[0]->apartments->[1]->rooms}, 1 );
is( $hotels[0]->apartments->[1]->rooms->[0]->column('size'), 10 );
is( @{$hotels[1]->apartments->[0]->rooms}, 1 );
is( $hotels[1]->apartments->[0]->rooms->[0]->column('size'), 8 );
is( @{$hotels[1]->apartments->[1]->rooms}, 1 );
is( $hotels[1]->apartments->[1]->rooms->[0]->column('size'), 10 );
is( @{$hotels[2]->apartments->[0]->rooms}, 1 );
is( $hotels[2]->apartments->[0]->rooms->[0]->column('size'), 7 );
is( @{$hotels[2]->apartments->[1]->rooms}, 1 );
is( $hotels[2]->apartments->[1]->rooms->[0]->column('size'), 7 );


# same test, but strict turned off
@hotels =
  Hotel->find( conn=>$conn,
    with => [ 'apartments.rooms' => { min=>{column=>'size', group=>'hotel_num_c', top=>2, strict=>0 } }] );
is( @hotels, 3);
is( @{$hotels[0]->apartments->[0]->rooms}, 1 );
is( $hotels[0]->apartments->[0]->rooms->[0]->column('size'), 8 );
is( @{$hotels[0]->apartments->[1]->rooms}, 1 );
is( $hotels[0]->apartments->[1]->rooms->[0]->column('size'), 10 );
is( @{$hotels[1]->apartments->[0]->rooms}, 1 );
is( $hotels[1]->apartments->[0]->rooms->[0]->column('size'), 8 );
is( @{$hotels[1]->apartments->[1]->rooms}, 1 );
is( $hotels[1]->apartments->[1]->rooms->[0]->column('size'), 10 );
is( @{$hotels[2]->apartments->[0]->rooms}, 1 );
is( $hotels[2]->apartments->[0]->rooms->[0]->column('size'), 7 );
is( @{$hotels[2]->apartments->[1]->rooms}, 2 );
is( $hotels[2]->apartments->[1]->rooms->[0]->column('size'), 7 );
is( $hotels[2]->apartments->[1]->rooms->[1]->column('size'), 7 );



ObjectDB::TestData::Hotel->delete($conn);
