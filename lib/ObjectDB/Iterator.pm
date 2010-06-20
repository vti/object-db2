package ObjectDB::Iterator;

use strict;
use warnings;

use base 'ObjectDB::Base';

__PACKAGE__->attr('cb');

sub next { shift->cb->(@_) }

1;
