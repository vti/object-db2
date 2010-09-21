package Apartment;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->has_many('rooms',
    map =>
      {hotel_num_b => 'hotel_num_c', apartment_num_b => 'apartment_num_c'})
  ->belongs_to('hotel', map => {hotel_num_b => 'hotel_num_a'})
  ->has_many('images', map => {image_num_b => 'image_num_c'});

1;
