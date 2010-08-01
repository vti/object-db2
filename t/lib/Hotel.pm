package Hotel;

use strict;
use warnings;

use base 'ObjectDB';

__PACKAGE__->schema->has_many( 'apartments', map=>{hotel_num_a => 'hotel_num_b'} );

1;
