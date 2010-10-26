package ObjectDB::Relationship::BelongsTo;

use strict;
use warnings;

use base 'ObjectDB::Relationship::Base';

use ObjectDB::Utils 'plural_to_single';

sub _detect_column_mapping {
    my $self = shift;

    unless (%{$self->map}) {
        my $foreign_name = plural_to_single($self->foreign_table);

        my $pk         = $foreign_name . '_id';
        my $foreign_pk = 'id';

        $self->map({$pk => $foreign_pk});
    }

    # Put mapping cols in array to get STRICT ORDER
    while (my ($from, $to) = each %{$self->map}) {
        push @{$self->map_from_cols}, $from;
        push @{$self->map_to_cols},   $to;
    }

    return;
}

sub to_source {
    my $self             = shift;
    my $passed_join_args = shift;
    my $alias_prefix     = shift || '';

    my $table         = $self->table;
    my $foreign_table = $self->foreign_table;


    my $as;
    if ($foreign_table eq $table) {
        $as = $alias_prefix.$self->name;
    }
    else {
        $as = $alias_prefix.$foreign_table;
    }

    my $constraint;

    while (my ($pk, $foreign_pk) = each %{$self->map}) {
        push @$constraint, "$as.$foreign_pk" => \qq/`$table`.`$pk`/;
    }

    if ($self->join_args) {
        my $i = 0;
        foreach my $value (@{$self->join_args}) {
            if ($i++ % 2) {
                push @$constraint, $value;
            }
            else {
                push @$constraint, "$as.$value";
            }
        }
    }


    if ($passed_join_args) {
        for (my $i = 0; $i < @{$passed_join_args}; $i += 2) {
            push @$constraint,
              $as . '.'
              . $passed_join_args->[$i] => $passed_join_args->[$i + 1];
        }
    }

    return {
        name       => $foreign_table,
        as         => $as,
        join       => 'left',
        constraint => $constraint
    };
}

1;
