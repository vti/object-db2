package Schema::Author;

use strict;
use warnings;

use base 'Schema::TestDB';

__PACKAGE__->schema->has_many('articles');

1;
