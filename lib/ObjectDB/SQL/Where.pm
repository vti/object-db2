package ObjectDB::SQL::Where;

use strict;
use warnings;

use base 'ObjectDB::SQL::Condition';

sub build {
    my $self = shift;

    my $string = $self->SUPER::build;
    return " WHERE $string" if $string;

    return '';
}

1;
