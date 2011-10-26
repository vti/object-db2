package ObjectDB::SQL::Insert::SQLite;

use strict;
use warnings;

use base 'ObjectDB::SQL::Insert::Base';

sub _default_values {
    my $self = shift;

    return ' DEFAULT VALUES';
}

1;
