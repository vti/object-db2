package AdminHistory;

use strict;
use warnings;

use base 'ObjectDB';

__PACKAGE__->schema->belongs_to('main_category');


1;
