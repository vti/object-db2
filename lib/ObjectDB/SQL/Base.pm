package ObjectDB::SQL::Base;

use strict;
use warnings;

use base 'ObjectDB::Base';

use overload '""' => sub { shift->to_string }, fallback => 1;
use overload 'bool' => sub { shift; }, fallback => 1;

require Carp;

use ObjectDB::SQL::Where;

sub BUILD {
    my $self = shift;

    Carp::croak('dbh is required') unless $self->{dbh};

    $self->{is_built} = 0  if not exists $self->{is_build};
    #$self->{columns}  = [] if not exists $self->{columns};
}

sub quote_value { shift->{dbh}->quote(@_) }
sub quote {
    my $self = shift;
    my ($name) = @_;

    return $self->{dbh}->quote_identifier($name);
}

sub quote_column {
    my $self = shift;
    my ($column, $prefix) = @_;

    # Prefixed
    if ($column =~ s/^(\w+)\.//) {
        $column = $self->quote($1) . '.' . $self->quote($column);
    }

    # Default prefix
    elsif ($prefix) {
        $column = $self->quote($prefix) . '.' . $self->quote($column);
    }

    # No Prefix
    else {
        $column = $self->quote($column);
    }

    return $column;
}

sub driver { shift->{dbh}->{'Driver'}->{'Name'} }

sub table    { @_ > 1 ? $_[0]->{table}    = $_[1] : $_[0]->{table} }

sub is_built { @_ > 1 ? $_[0]->{is_built} = $_[1] : $_[0]->{is_built} }
sub to_string {
    my $self = shift;

    die 'must be overloaded';
}

1;
