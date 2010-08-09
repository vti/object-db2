package ObjectDB::Relationship::HasMany;

use strict;
use warnings;

use base 'ObjectDB::Relationship::Base';

sub _build {
    my $self = shift;

    $self->_prepare_foreign(@_, 'single');

    unless (%{$self->map}) {
        my $foreign_name =
          ObjectDB::Util->plural_to_single($self->table);

        my $pk         = 'id';
        my $foreign_pk = $foreign_name . '_' . $pk;

        $self->map({$pk => $foreign_pk});
    }

    return;
}

sub to_source {
    my $self = shift;

    my $table         = $self->table;
    my $foreign_table = $self->foreign_table;

    my $as;
    if ($table eq $foreign_table) {
        $as = $self->name;
    }
    else {
        $as = $foreign_table;
    }

    my @constraints;
    while (my ($from, $to) = each %{$self->map}) {
        push @constraints, "$as.$to" => "$table.$from";
    }


    my @args = ();
    if ($self->{where}) {
        for (my $i = 0; $i < @{$self->{where}}; $i += 2) {
            push @args,
              $as . '.' . $self->{where}->[$i] => $self->{where}->[$i + 1];
        }
    }

    if ($self->join_args) {
        my $i = 0;
        foreach my $value (@{$self->join_args}) {
            if ($i++ % 2) {
                push @args, $value;
            }
            else {
                push @args, "$as.$value";
            }
        }
    }

    return {
        name       => $foreign_table,
        join       => 'left',
        as         => $as,
        constraint => [@constraints, @args]
    };
}

1;
