package Image;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->belongs_to('article', map => {img_num => 'img_number'} );
1;
