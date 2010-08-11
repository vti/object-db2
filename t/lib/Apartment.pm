package Apartment;

use strict;
use warnings;

use base 'ObjectDB';

__PACKAGE__->schema
  ->has_many( 'rooms', map=>{hotel_num_b => 'hotel_num_c', apartment_num_b => 'apartment_num_c'} )
  ->belongs_to( 'hotel', map=>{hotel_num_b => 'hotel_num_a'} );

1;
