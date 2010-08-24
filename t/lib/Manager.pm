package Manager;

use strict;
use warnings;

use base 'ObjectDB';

__PACKAGE__->schema->has_many('telefon_numbers',
    map => {hotel_num_b => 'hotel_num_c', manager_num_b => 'manager_num_c'});

1;
