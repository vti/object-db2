package Room;

use strict;
use warnings;

use base 'ObjectDB';

__PACKAGE__->schema->belongs_to('apartment', map=>{hotel_num_c => 'hotel_num_b', apartment_num_c => 'apartment_num_b'})
    ->belongs_to('maid', map=>{hotel_num_c => 'hotel_num_d', apartment_num_c => 'apartment_num_c', room_num_c => 'room_num_d'} );

1;
