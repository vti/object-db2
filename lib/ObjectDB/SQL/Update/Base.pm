package ObjectDB::SQL::Update::Base;

use strict;
use warnings;

use base 'ObjectDB::SQL::Base';

sub BUILD {
    my $self = shift;

    $self->{values}  = [] unless exists $self->{sources};
    $self->{columns} = [] unless exists $self->{columns};
}

sub columns { @_ > 1 ? $_[0]->{columns} = $_[1] : $_[0]->{columns} }
sub values  { @_ > 1 ? $_[0]->{values}  = $_[1] : $_[0]->{values} }

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

sub where {
    my $self = shift;

    # Lazy initialization
    $self->{where} ||= ObjectDB::SQL::Where->new(dbh => $self->{dbh});

    # Get
    return $self->{where} unless @_;

    # Set
    $self->{where}->cond(@_);

    # Rebuild
    $self->is_built(0);

    return $self;
}

sub bind {
    my $self = shift;

    # Initialize
    $self->{bind} ||= [];

    # Get
    return $self->{bind} unless @_;

    # Set
    if (ref $_[0] eq 'ARRAY') {
        push @{$self->{bind}}, @{$_[0]};
    }
    else {
        push @{$self->{bind}}, $_[0];
    }

    return $self;
}
sub to_string {
    my $self = shift;

    return $self->{to_string} if $self->{to_string};

    $self->build;

    my $query = "";

    $query .= 'UPDATE ';
    $query .= $self->quote($self->table);
    $query .= ' SET ';

    my $i     = @{$self->columns} - 1;
    my $count = 0;
    foreach my $name (@{$self->columns}) {
        my $value = $self->values->[$count];

        if (ref $value eq 'SCALAR') {
            $query .= $self->quote($name) . " = $$value";
        }
        else {
            $query .= $self->quote($name) . " = ?";
        }

        $query .= ', ' if $i;
        $i--;
        $count++;
    }

    $query .= $self->where;
    $self->bind($self->where->bind);

    #$self->is_built(1);

    return $self->{to_string} = $query;
}

1;
