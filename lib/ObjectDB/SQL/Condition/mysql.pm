package ObjectDB::SQL::Condition::mysql;

use strict;
use warnings;

use base 'ObjectDB::SQL::Condition::Base';

sub _concat {
    my $self = shift;

    return 'CONCAT_WS("__",' . join(',', @_) . ')';
}

1;
