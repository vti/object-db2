package ObjectDB::Relationship::HasAndBelongsToMany;

use strict;
use warnings;

use base 'ObjectDB::Relationship::Base';

use ObjectDB::Loader;
use ObjectDB::Util;

__PACKAGE__->attr([qw/map_class map_from map_to/]);

sub _build {
    my $self = shift;

    unless ($self->foreign_class) {
        my $foreign_class = ObjectDB::Util->plural_to_single($self->name);
        $foreign_class = ObjectDB::Util->camelize($foreign_class);

        ObjectDB::Loader->load($foreign_class);
        $foreign_class->schema->build(@_);

        $self->foreign_class($foreign_class);
    }

    unless ($self->foreign_table) {
        $self->foreign_table($self->foreign_class->schema->table);
    }

    unless ($self->map_from) {
        $self->map_from(ObjectDB::Util->plural_to_single($self->table));
    }

    unless ($self->map_to) {
        $self->map_to(ObjectDB::Util->plural_to_single($self->name));
    }

    unless ($self->map_class) {
        my $map_class  = $self->class . $self->foreign_class . 'Map';
        my $map_table = ObjectDB::Util->class_to_table($map_class);

        my $from = $self->map_from;
        my $to   = $self->map_to;

        my $package = <<"EOF";
package $map_class;
use base 'ObjectDB';
__PACKAGE__->schema('$map_table')->belongs_to('$from')->belongs_to('$to');
1;
EOF

        eval $package;
        die qq/Couldn't initialize class "$map_class": $@/ if $@;

        $map_class->schema->build(@_);

        while (my ($key, $value) = each %{$map_class->schema->relationships}) {
            $value->build(@_);
        }

        $self->map_class($map_class);
    }

    return;
}

sub map_schema { shift->map_class->schema }
sub map_table { shift->map_schema->table }

sub to_source {
    my $self = shift;

    my $map_from = $self->map_from;
    my $map_to   = $self->map_to;

    my ($from, $to) =
      %{$self->map_schema->relationships->{$map_to}->map};

    my $table     = $self->foreign_table;
    my $map_table = $self->map_table;

    my $as = $self->name;

    return {
        name       => $table,
        as         => $table,
        join       => 'left',
        constraint => ["$table.$to" => "$map_table.$from"]
    };
}

sub to_map_source {
    my $self = shift;
    my %params = @_;

    my $map_from = $self->map_from;
    my $map_to   = $self->map_to;

    my ($from, $to) =
      %{$self->map_schema->relationships->{$map_from}->map};

    my $table     = $self->table;
    my $map_table = $self->map_table;

    return {
        name       => $map_table,
        join       => 'left',
        constraint => ["$table.$to" => "$map_table.$from"]
    };
}

sub to_self_map_source {
    my $self = shift;

    my $map_from = $self->map_from;
    my $map_to   = $self->map_to;

    my ($from, $to) =
      %{$self->map_schema->relationships->{$map_to}->map};

    my $table     = $self->foreign_table;
    my $map_table = $self->map_table;

    return {
        name       => $map_table,
        join       => 'left',
        constraint => ["$table.$to" => "$map_table.$from"]
    };
}

sub to_self_source {
    my $self = shift;

    my $map_from = $self->map_from;
    my $map_to   = $self->map_to;

    my ($from, $to) =
      %{$self->map_schema->relationships->{$map_from}->map};

    my $table     = $self->table;
    my $map_table = $self->map_table;

    return {
        name       => $table,
        as         => $table,
        join       => 'left',
        constraint => ["$table.$to" => "$map_table.$from"]
    };
}

1;
