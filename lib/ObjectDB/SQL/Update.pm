package ObjectDB::SQL::Update;

use strict;
use warnings;

use base 'ObjectDB::SQL::Base';

__PACKAGE__->attr(values => sub { [] });

sub build {
    my $self = shift;

    my $count = 0;
    foreach my $name (@{$self->columns}) {
        my $value = $self->values->[$count];

        $self->bind($value) unless ref($value) eq 'SCALAR';

        $count++;
    }


    return $self;
}

sub to_string {
    my $self = shift;

    $self->build unless $self->is_built;

    my $query = "";

    $query .= 'UPDATE ';
    $query .= $self->escape($self->table);
    $query .= ' SET ';

    my $i     = @{$self->columns} - 1;
    my $count = 0;
    foreach my $name (@{$self->columns}) {
        my $value = $self->values->[$count];

        if (ref $value eq 'SCALAR') {
            $query .= $self->escape($name) . " = $$value";
        }
        else {
            $query .= $self->escape($name) . " = ?";
        }

        $query .= ', ' if $i;
        $i--;
        $count++;
    }

    $query .= $self->where;
    $self->bind($self->where->bind) unless $self->is_built;
    $self->is_built(1);

    return $query;
}

1;
