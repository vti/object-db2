package ObjectDB::SQL::Delete::Base;

use strict;
use warnings;

use base 'ObjectDB::SQL::Base';

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

    my $query = "";

    $query .= 'DELETE FROM ';
    $query .= $self->quote($self->table);
    $query .= $self->where;

    $self->{bind} = [];
    $self->bind($self->where->bind);

    return $query;
}

1;
