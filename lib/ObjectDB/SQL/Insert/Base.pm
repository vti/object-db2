package ObjectDB::SQL::Insert::Base;

use strict;
use warnings;

use base 'ObjectDB::SQL::Base';

sub BUILD {
    my $self = shift;

    $self->{columns}  = [] unless exists $self->{columns};
}

sub columns  { @_ > 1 ? $_[0]->{columns}  = $_[1] : $_[0]->{columns} }

sub to_string {
    my $self = shift;

    my $query = "";

    $query .= 'INSERT INTO ';
    $query .= $self->quote($self->table);
    if (@{$self->columns}) {
        $query .= ' (';
        $query .= join(', ', map { $self->quote($_) } @{$self->columns});
        $query .= ')';
        $query .= ' VALUES (';
        $query .= '?, ' x (@{$self->columns} - 1);
        $query .= '?)';
    }
    else {
        $query .= $self->_default_values;
    }

    return $query;
}

1;
