package ObjectDB::SQL::Insert;

use strict;
use warnings;

use ObjectDB::SQL::Factory;

sub new {
    my $class = shift;

    return ObjectDB::SQL::Factory->new('Insert', @_);
}

1;
