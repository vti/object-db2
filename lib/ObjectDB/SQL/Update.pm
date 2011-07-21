package ObjectDB::SQL::Update;

use strict;
use warnings;

use base 'ObjectDB::SQL::Base';

use ObjectDB::SQL::Utils 'escape';

sub BUILD {
    my $self = shift;
    $self->{values} = [] if not exists $self->{sources};
}

sub values { @_ > 1 ? $_[0]->{values} = $_[1] : $_[0]->{values} }

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
    $query .= escape($self->table);
    $query .= ' SET ';

    my $i     = @{$self->columns} - 1;
    my $count = 0;
    foreach my $name (@{$self->columns}) {
        my $value = $self->values->[$count];

        if (ref $value eq 'SCALAR') {
            $query .= escape($name) . " = $$value";
        }
        else {
            $query .= escape($name) . " = ?";
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
