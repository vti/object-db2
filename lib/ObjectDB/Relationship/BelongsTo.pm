package ObjectDB::Relationship::BelongsTo;

use strict;
use warnings;

use base 'ObjectDB::Relationship::Base';

use ObjectDB::Utils 'plural_to_single';

sub _build {
    my $self = shift;

    $self->_prepare_foreign(@_);

    unless (%{$self->map}) {
        my $foreign_name = plural_to_single($self->foreign_table);

        my $pk         = $foreign_name . '_id';
        my $foreign_pk = 'id';

        $self->map({$pk => $foreign_pk});
    }

    return;
}

sub to_source {
    my $self             = shift;
    my $passed_join_args = shift;

    my $table         = $self->table;
    my $foreign_table = $self->foreign_table;


    my $as;
    if ($foreign_table eq $table) {
        $as = $self->name;
    }
    else {
        $as = $foreign_table;
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
