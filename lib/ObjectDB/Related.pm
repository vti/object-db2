package ObjectDB::Related;

use strict;
use warnings;

use base 'ObjectDB::Base';

sub set {
    my $self = shift;
    my ($name, $value) = @_;

    $self->{related}->{$name} = $value;

    return $self;
}

sub push {
    my $self = shift;
    my $name = shift;

    my $related = $self->{related}->{$name} ||= [];

    if (ref $related ne 'ARRAY') {
        $self->{related}->{$name} = [$related];
    }

    push @{$self->{related}->{$name}}, @_;

    return $self;
}

sub get {
    my $self = shift;
    my ($name) = @_;

    return $self->{related}->{$name};
}

sub delete {
    my $self = shift;
    my ($name) = @_;

    delete $self->{related}->{$name};
}

sub names {
    my $self = shift;

    return keys %{$self->{related}};
}

1;
