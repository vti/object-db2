package ObjectDB::SQL::Delete;

use strict;
use warnings;

use ObjectDB::SQL::Factory;

sub new {
    my $class = shift;

    return ObjectDB::SQL::Factory->new('Delete', @_);
}

1;
