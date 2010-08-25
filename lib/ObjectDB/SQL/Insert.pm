package ObjectDB::SQL::Insert;

use strict;
use warnings;

use base 'ObjectDB::SQL::Base';

use ObjectDB::SQL::Utils 'escape';

sub to_string {
    my $self = shift;

    my $query = "";

    $query .= 'INSERT INTO ';
    $query .= escape($self->table);
    if (@{$self->columns}) {
        $query .= ' (';
        $query .= join(', ', map { escape($_) } @{$self->columns});
        $query .= ')';
        $query .= ' VALUES (';
        $query .= '?, ' x (@{$self->columns} - 1);
        $query .= '?)';
    }
    else {
        if ($self->driver && $self->driver eq 'mysql') {
            $query .= '() VALUES()';
        }
        else {
            $query .= ' DEFAULT VALUES';
        }
    }

    return $query;
}

1;
