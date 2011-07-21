package ObjectDB::Rows;

use strict;
use warnings;

use base 'ObjectDB::Base';

#__PACKAGE__->attr('rows');

sub BUILD {
    my $self = shift;

    $self->{next_counter} = 0 unless defined $self->{next_counter};
    $self->{rows} ||= [];

    return $self;
}

sub row {
    my $self = shift;
    my $num  = shift;

    return $self->rows->[$num];
}

sub rows {
    my $self = shift;

    if (@_) {
        $self->{rows} = $_[0];
        return $self;
    }

    return $self->{rows};
}

sub number_of_rows {
    my $self = shift;
    return scalar(@{$self->rows}) if $self->rows;
}

sub next {
    my $self = shift;

    my $number_of_rows = scalar(@{$self->rows});

    my $next_counter = $self->{next_counter};

    if ($next_counter > $number_of_rows - 1) {
        $self->{next_counter} = 0;
        return undef;
    }
    else {
        my $row = $self->rows->[$next_counter];
        $next_counter++;

        $self->{next_counter} = $next_counter;
        return $row;
    }
}

sub to_hash {
    my $self = shift;

    my @objects;
    while (my $object = $self->next){
        my $hash = $object->to_hash;
        push @objects, $hash;
    }

    return [@objects];

}


1;
