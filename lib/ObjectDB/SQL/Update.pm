package ObjectDB::SQL::Update;

use strict;
use warnings;

use ObjectDB::SQL::Factory;

sub new {
    my $class = shift;

    return ObjectDB::SQL::Factory->new('Update', @_);
}

1;
