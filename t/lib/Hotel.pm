package Hotel;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->has_many('apartments',
    map => {hotel_num_a => 'hotel_num_b'})
  ->has_one('manager', map => {hotel_num_a => 'hotel_num_b'})
  ->has_one('parking_lot',
    map => {lot_id_1_h => 'lot_id_1_l', lot_id_2_h => 'lot_id_2_l'});

1;
