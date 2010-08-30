package ObjectDB::Relationship::HasAndBelongsToMany;

use strict;
use warnings;

use base 'ObjectDB::Relationship::Base';

__PACKAGE__->attr([qw/map_class map_from map_to/]);

use ObjectDB::Utils qw/plural_to_single class_to_table/;

sub _detect_column_mapping {
    my $self = shift;

    unless ($self->map_from) {
        $self->map_from(plural_to_single($self->table));
    }

    unless ($self->map_to) {
        $self->map_to(plural_to_single($self->name));
    }

    unless ($self->map_class) {

        # Because we have two points of view :)
        my @classes = ($self->class, $self->foreign_class);

        if ($self->namespace) {
            @classes = grep { s/^\Q$self->{namespace}::\E// } @classes;
        }

        my $map_class = join('', sort(@classes)) . 'Map';

        $map_class = join '::', $self->namespace, $map_class
          if $self->namespace;

        unless ($map_class->can('new')) {
            my $map_table = class_to_table($map_class);

            my $from = $self->map_from;
            my $to   = $self->map_to;

            my $ns = $self->{namespace} || '';
            my $package = <<"EOF";
package $map_class;
use base 'ObjectDB';
sub namespace { '$ns' }
__PACKAGE__->schema('$map_table')->belongs_to('$from')->belongs_to('$to');
1;
EOF
            eval $package;

            die qq/Couldnt initialize class "$map_class": $@/ if $@;
        }

        $self->map_class($map_class);
    }

    return;
}

sub map_schema { shift->map_class->schema }
sub map_table  { shift->map_schema->table }

sub to_source {
    my $self = shift;

    my $map_from = $self->map_from;
    my $map_to   = $self->map_to;

    my ($from, $to) = %{$self->map_schema->relationships->{$map_to}->map};

    my $table     = $self->foreign_table;
    my $map_table = $self->map_table;

    my $as = $self->name;

    return {
        name       => $table,
        as         => $table,
        join       => 'left',
        constraint => ["$table.$to" => \qq/`$map_table`.`$from`/]
    };
}

sub to_map_source {
    my $self   = shift;
    my %params = @_;

    my $map_from = $self->map_from;
    my $map_to   = $self->map_to;

    my ($from, $to) = %{$self->map_schema->relationships->{$map_from}->map};

    my $table     = $self->table;
    my $map_table = $self->map_table;

    return {
        name       => $map_table,
        join       => 'left',
        constraint => ["$table.$to" => \qq/`$map_table`.`$from`/]
    };
}

sub to_self_map_source {
    my $self = shift;

    my $map_from = $self->map_from;
    my $map_to   = $self->map_to;

    my ($from, $to) = %{$self->map_schema->relationships->{$map_to}->map};

    my $table     = $self->foreign_table;
    my $map_table = $self->map_table;

    return {
        name       => $map_table,
        join       => 'left',
        constraint => ["$table.$to" => \qq/`$map_table`.`$from`/]
    };
}

sub to_self_source {
    my $self = shift;

    my $map_from = $self->map_from;
    my $map_to   = $self->map_to;

    my ($from, $to) = %{$self->map_schema->relationships->{$map_from}->map};

    my $table     = $self->table;
    my $map_table = $self->map_table;

    return {
        name       => $table,
        as         => $table,
        join       => 'left',
        constraint => ["$table.$to" => \qq/`$map_table`.`$from`/]
    };
}

1;
