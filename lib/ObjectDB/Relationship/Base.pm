package ObjectDB::Relationship::Base;

use strict;
use warnings;

use base 'ObjectDB::Base';

require ObjectDB::Loader;
use ObjectDB::Utils qw/camelize decamelize class_to_table plural_to_single/;

__PACKAGE__->attr([qw/name foreign_class foreign_table namespace/]);
__PACKAGE__->attr([qw/map/]                  => sub { {} });
__PACKAGE__->attr([qw/with where join_args/] => sub { [] });
__PACKAGE__->attr(is_built                   => 0);

sub type { decamelize((split '::' => ref(shift))[-1]) }

sub class {
    my $self = shift;

    my $class = $self->{class};

    ObjectDB::Loader->load($class);

    return $self->{class};
}

sub table {
    my $self = shift;

    return $self->{table} if $self->{table};

    $self->{table} = class_to_table($self->class);

    return $self->{table};
}

sub build {
    my $self = shift;

    return if $self->is_built;

    # Create alias for parent class to access related data
    $self->_create_alias_for_related_data;

    $self->_detect_and_load_foreign_class;

    $self->_detect_foreign_table(@_);

    $self->_detect_column_mapping(@_);

    $self->is_built(1);

    # Now build other schemas (and other relationships) AFTER
    # current rel is flaged as build
    $self->foreign_class->schema->build(@_) if $self->foreign_class;
    $self->map_class->schema->build(@_) if $self->can('map_class');

}

sub _create_alias_for_related_data {
    my $self = shift;

    unless ($self->class->can($self->name)) {
        no strict;
        my $class = $self->class;
        my $name  = $self->name;
        my $code  = "sub {shift->related('$name')}";
        *{"${class}::$name"} = eval $code;
    }
}

sub _detect_and_load_foreign_class {
    my $self = shift;

    return if $self->is_type('proxy');

    if (my $foreign_class = $self->foreign_class) {
        if (my $namespace = $self->namespace) {
            $self->foreign_class($namespace . '::' . $foreign_class);
        }
    }
    else {
        my $foreign_class = camelize($self->name);

        $foreign_class = plural_to_single($foreign_class)
          if ($self->is_type(qw/has_many has_and_belongs_to_many/));

        if (my $namespace = $self->namespace) {
            $foreign_class = $namespace . '::' . $foreign_class;
        }

        $self->foreign_class($foreign_class);
    }

    ObjectDB::Loader->load($self->foreign_class);

}

sub _detect_foreign_table {
    my ($self) = shift;

    return if $self->is_type('proxy');

    unless ($self->foreign_table) {
        $self->foreign_table($self->foreign_class->schema->table);
    }
}

sub is_belongs_to              { shift->is_type('belongs_to') }
sub is_belongs_to_one          { shift->is_type('belongs_to_one') }
sub is_has_and_belongs_to_many { shift->is_type('has_and_belongs_to_many') }
sub is_has_many                { shift->is_type('has_many') }
sub is_has_one                 { shift->is_type('has_one') }

sub is_type {
    my $self = shift;

    return (grep { $_ eq $self->type } @_) ? 1 : 0;
}

sub _detect_column_mapping { }

1;
