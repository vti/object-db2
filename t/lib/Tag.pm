package Tag;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->has_and_belongs_to_many('articles')
  ->has_many('admin_histories');

1;
