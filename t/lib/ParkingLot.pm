package ParkingLot;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->has_many('parking_spots');

1;
