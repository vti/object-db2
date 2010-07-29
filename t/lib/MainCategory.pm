package MainCategory;

use strict;
use warnings;

use base 'ObjectDB';

__PACKAGE__->schema->has_many('articles')->has_many('admin_histories');


1;
