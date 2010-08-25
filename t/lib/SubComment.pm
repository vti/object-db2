package SubComment;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->belongs_to('comment');


1;
