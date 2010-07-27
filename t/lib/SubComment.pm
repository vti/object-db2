package SubComment;

use strict;
use warnings;

use base 'ObjectDB';

__PACKAGE__->schema->belongs_to('comment');


1;
