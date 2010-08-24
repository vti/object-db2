package SpecialReport;

use strict;
use warnings;

use base 'ObjectDB';

__PACKAGE__->schema->belongs_to('main_category')->has_many('articles');
1;
