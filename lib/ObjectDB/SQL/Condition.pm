package ObjectDB::SQL::Condition;

use strict;
use warnings;

use ObjectDB::SQL::Factory;

sub new {
    my $class = shift;

    return ObjectDB::SQL::Factory->new('Condition', @_);
}

1;
