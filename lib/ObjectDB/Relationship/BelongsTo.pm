package ObjectDB::Relationship::BelongsTo;

use strict;
use warnings;

use base 'ObjectDB::Relationship::Base';

use ObjectDB::Util;
use ObjectDB::Loader;

sub _build {
    my $self = shift;

    unless ($self->foreign_class) {
        my $foreign_class = ObjectDB::Util->camelize($self->name);

        ObjectDB::Loader->load($foreign_class);
        $foreign_class->schema->build(@_);

        $self->foreign_class($foreign_class);
    }

    unless ($self->foreign_table) {
        $self->foreign_table($self->foreign_class->schema->table);
    }

    unless (%{$self->map}) {
        my $foreign_name =
          ObjectDB::Util->plural_to_single($self->foreign_table);

        my $pk         = $foreign_name . '_id';
        my $foreign_pk = 'id';

        $self->map({$pk => $foreign_pk});
    }

    return;
}

sub to_source {
    my $self   = shift;

    my $table         = $self->table;
    my $foreign_table = $self->foreign_table;

    my ($pk, $foreign_pk) = %{$self->map};

    my $as;
    if ($foreign_table eq $table) {
        $as = $self->name;
    }
    else {
        $as = $foreign_table;
    }

    my $constraint = ["$as.$foreign_pk" => "$table.$pk"];

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

    return {
        name       => $foreign_table,
        as         => $as,
        join       => 'left',
        constraint => $constraint
    };
}

1;
