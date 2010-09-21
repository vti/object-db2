package Image;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->belongs_to('apartment', map => {imgage_num_c => 'imgage_num_b'} );

1;
