package Comment;

use strict;
use warnings;

use base 'ObjectDB';

__PACKAGE__->schema->belongs_to('article')->belongs_to('author')->has_many('sub_comments');

1;
