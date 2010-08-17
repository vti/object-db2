#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 56;

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




ObjectDB::TestData::Hotel->delete($conn);
