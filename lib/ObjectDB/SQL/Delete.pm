package ObjectDB::SQL::Delete;

use strict;
use warnings;

use base 'ObjectDB::SQL::Base';

sub to_string {
    my $self = shift;

    my $query = "";

    $query .= 'DELETE FROM ';
    $query .= $self->escape($self->table);
    $query .= $self->where;
    $self->bind( $self->where->bind );

    return $query;
}

1;
