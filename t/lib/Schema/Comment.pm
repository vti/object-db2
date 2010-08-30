package Schema::Comment;

use strict;
use warnings;

use base 'Schema::TestDB';

__PACKAGE__->schema->belongs_to('article');

1;
