package ObjectDB::SQL::Condition::SQLite;

use strict;
use warnings;

use base 'ObjectDB::SQL::Condition::Base';

sub _concat {
    my $self = shift;

    return join(' || "__" || ', @_);
}

1;
