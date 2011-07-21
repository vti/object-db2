package ObjectDB::Iterator;

use strict;
use warnings;

use base 'ObjectDB::Base';

sub next { shift->{cb}->(@_) }

1;
