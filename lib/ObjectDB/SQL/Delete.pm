package ObjectDB::SQL::Delete;

use strict;
use warnings;

use base 'ObjectDB::SQL::Base';

use ObjectDB::SQL::Utils 'escape';

sub to_string {
    my $self = shift;

    my $query = "";

    $query .= 'DELETE FROM ';
    $query .= escape($self->table);
    $query .= $self->where;

    $self->{bind} = [];
    $self->bind($self->where->bind);

    return $query;
}

1;
