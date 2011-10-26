package ObjectDB::SQL::Select;

use strict;
use warnings;

use ObjectDB::SQL::Factory;

sub new {
    my $class = shift;

    return ObjectDB::SQL::Factory->new('Select', @_);
}

1;
