package ObjectDB::SQL::Base;

use strict;
use warnings;

use base 'ObjectDB::Base';

use ObjectDB::SQL::Where;

sub BUILD {
    my $self = shift;
    $self->{is_built} = 0  if not exists $self->{is_build};
    $self->{columns}  = [] if not exists $self->{columns};
}

sub is_built   { @_ > 1 ? $_[0]->{is_built} = $_[1] : $_[0]->{is_built} }
sub driver   { @_ > 1 ? $_[0]->{driver} = $_[1] : $_[0]->{driver} }
sub table    { @_ > 1 ? $_[0]->{table} = $_[1] : $_[0]->{table} }
sub order_by { @_ > 1 ? $_[0]->{order_by} = $_[1] : $_[0]->{order_by} }
sub limit    { @_ > 1 ? $_[0]->{limit} = $_[1] : $_[0]->{limit} }
sub offset   { @_ > 1 ? $_[0]->{offset} = $_[1] : $_[0]->{offset} }
sub columns  { @_ > 1 ? $_[0]->{columns} = $_[1] : $_[0]->{columns} }

use overload '""' => sub { shift->to_string }, fallback => 1;
use overload 'bool' => sub { shift; }, fallback => 1;

sub where {
    my $self = shift;

    # Lazy initialization
    $self->{where} ||= ObjectDB::SQL::Where->new({driver => $self->driver});

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

    die 'must be overloaded';
}

1;
