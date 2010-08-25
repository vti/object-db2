package AuthorAdmin;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->belongs_to('author');

1;
