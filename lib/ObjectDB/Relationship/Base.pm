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

    unless ($self->class->can($self->name)) {
        no strict;
        my $class = $self->class;
        my $name  = $self->name;
        my $code  = "sub {shift->related('$name')}";
        *{"${class}::$name"} = eval $code;
    }

    $self->_build(@_);

    $self->is_built(1);

    # Now build other schemas (and other relationships) after
    # current rel is flaged as build
    $self->foreign_class->schema->build(@_) if $self->foreign_class;
    $self->map_class->schema->build(@_) if $self->can("map_class");

}

sub _prepare_foreign {
    my ($self) = shift;
    my $single = $_[$#_] eq 'single' ? pop : undef;

    if (my $foreign_class = $self->foreign_class) {
        # Check if short version has been passed
        if (my $namespace = $self->namespace) {
            $self->foreign_class($namespace . '::' . $foreign_class);
        }
    }
    else {
        my $foreign_class = camelize($self->name);

        $foreign_class = plural_to_single($foreign_class)
          if $single;

        if (my $namespace = $self->namespace) {
            $foreign_class = $namespace . '::' . $foreign_class;
        }

        $self->foreign_class($foreign_class);
    }

    ObjectDB::Loader->load($self->foreign_class);

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

sub _build { }

1;
