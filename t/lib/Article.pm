package Article;

use strict;
use warnings;

use base 'ObjectDB';

__PACKAGE__->schema
  ->belongs_to('author')
  ->has_and_belongs_to_many('tags')
  ->has_many('comments');
1;
