package Comment;

use strict;
use warnings;

use base 'ObjectDB';

__PACKAGE__->schema->belongs_to('article')->belongs_to('author');

1;
