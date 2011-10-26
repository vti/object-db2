package User;

use strict;
use warnings;

use base 'Author';

__PACKAGE__->schema->add_column('active');

1;
