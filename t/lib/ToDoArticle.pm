package ToDoArticle;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->belongs_to('article');

1;
