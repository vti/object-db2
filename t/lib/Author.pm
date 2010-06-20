package Author;

use strict;
use warnings;

use base 'ObjectDB';

__PACKAGE__->schema->has_one('author_admin');

1;
