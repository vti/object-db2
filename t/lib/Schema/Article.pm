package Schema::Article;

use strict;
use warnings;

use base 'Schema::TestDB';

__PACKAGE__->schema->belongs_to('author')->has_many('comments')->has_and_belongs_to_many('tags');
1;
