package ObjectDB::Rows;

use strict;
use warnings;

use base 'ObjectDB::Base';

__PACKAGE__->attr('rows');
__PACKAGE__->attr('next_counter' => 0);

sub row {
    my $self = shift;
    my $num  = shift;

    return $self->rows->[$num];
}

sub number_of_rows {
    my $self = shift;
    return scalar(@{$self->rows}) if $self->rows;
}

sub next {
    my $self = shift;

    my $number_of_rows = scalar(@{$self->rows});

    my $next_counter = $self->next_counter;

    if ($next_counter > $number_of_rows - 1) {
        $self->next_counter(0);
        return undef;
    }
    else {
        my $row = $self->rows->[$next_counter];
        $next_counter++;

        $self->next_counter($next_counter);
        return $row;
    }
}

1;
