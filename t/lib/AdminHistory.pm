package AdminHistory;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->belongs_to('main_category')->belongs_to('tag');


1;
