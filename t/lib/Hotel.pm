package Hotel;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->has_many('apartments',
    map => {hotel_num_a => 'hotel_num_b'})
  ->has_one('manager', map => {hotel_num_a => 'hotel_num_b'});

1;
