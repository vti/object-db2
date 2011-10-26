package ObjectDB::SQL::Insert::mysql;

use strict;
use warnings;

use base 'ObjectDB::SQL::Insert::Base';

sub _default_values {
    my $self = shift;

    return ' () VALUES()';
}

1;
