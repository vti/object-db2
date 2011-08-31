package ObjectDB::Schema;

use strict;
use warnings;

use base 'ObjectDB::Base';

require Carp;
use Class::Load ();
use Storable ();

use ObjectDB::SchemaDiscoverer;
use ObjectDB::Utils qw/camelize decamelize class_to_table/;

my $TYPES = {
    'one to one'   => 'has_one',
    'one to many'  => 'has_many',
    'many to one'  => 'belongs_to',
    'many to many' => 'has_and_belongs_to_many'
};

our %objects;

sub new {
    my $self = shift->SUPER::new(@_);

    foreach my $parent (_get_parents($self->class)) {
        if (exists $objects{$parent}) {
            my $parent_schema = $objects{$parent};
            my $schema = Storable::dclone($parent_schema);

            $schema->class($self->class);

            return $schema;
        }
    }

    $self->{columns} ||= [];

    for (qw/primary_key unique_keys/) {
        if (defined $self->{$_}) {
            $self->{$_} = [$self->{$_}]
              unless ref $self->{$_} eq 'ARRAY';
        }
        else {
            $self->{$_} ||= [];
        }
    }

    unless ($self->table) {
        my $class = $self->class;

        Class::Load::load_class($class);

        my $plural_class_name =
          $class->can('plural_class_name') ? $class->plural_class_name : '';
        my $table = class_to_table($class, $plural_class_name);

        $self->{table} = $table;
    }

    if (my $relationships = delete $self->{relationships}) {
        foreach my $name (keys %$relationships) {
            my $rel = $relationships->{$name};
            my $type = delete $rel->{type};
            die "Unknown relationship type '$type'" unless exists $TYPES->{$type};
            $type = $TYPES->{$type};
            $self->_new_relationship($type, $name, %$rel);
        }
    }

    return $self;
}

sub BUILD {
    my $self = shift;

    $self->{relationships} ||= {};

    return $self;
}

sub table          { $_[0]->{table} }
sub class          { @_ > 1 ? $_[0]->{class} = $_[1] : $_[0]->{class} }
sub relationships  { $_[0]->{relationships} }

sub namespace { @_ > 1 ? $_[0]->{namespace} = $_[1] : $_[0]->{namespace} }

sub build {
    my $self = shift;

    # Cache
    return if $self->{is_built};

    $ENV{OBJECTDB_BUILT_SCHEMAS}++;

    $self->auto_discover(@_) unless $self->columns;

    my $class = $self->class;

    # Prevent recursive discovery
    $self->{is_built} = 1;

    $self->build_relationships(@_)
      unless $self->class->can('objectdb_lazy')
          && $self->class->objectdb_lazy;

    $self->build_aliases(@_);

    return $self;
}

sub auto_discover {
    my $self = shift;
    my $dbh = shift;

    Carp::croak qq/dbh is required for automatic column discovery/
      unless $dbh;

    my $discoverer = ObjectDB::SchemaDiscoverer->build(
        driver => $dbh->{'Driver'}->{'Name'},
        table  => $self->table
    );

    $discoverer->discover($dbh);

    $self->add_column($_) for @{$discoverer->columns};

    $self->add_to_primary_key($_) for @{$discoverer->primary_key};

    $self->unique_keys($_) for @{$discoverer->unique_keys};

    $self->{auto_increment} = $discoverer->auto_increment
      if $discoverer->auto_increment;
}

sub build_relationships {
    my $self = shift;

    while (my ($key, $value) = each %{$self->{relationships}}) {
        $value->build(@_);
    }
}

sub build_aliases {
    my $self = shift;

    my $class = $self->class;
    for my $column ($self->columns) {
        unless ($self->class->can($column)) {
            no strict;
            my $code  = "sub {my \$self = shift; \$self->column('$column', \@_)}";
            *{"${class}::$column"} = eval $code;
        }
    }

    while (my ($key, $rel) = each %{$self->{relationships}}) {
        unless ($self->class->can($rel->name)) {
            no strict;
            my $class = $rel->class;
            my $name  = $rel->name;
            my $code  = "sub {shift->related('$name')}";
            *{"${class}::$name"} = eval $code;
        }
    }
}

sub auto_increment {
    my $self = shift;

    return $self->{auto_increment} unless @_;

    $self->{auto_increment} = $_[0];

    return $self;
}

sub columns {
    my $self = shift;

    return @{$self->{columns} || []} unless @_;

    $self->{columns} = @_ == 1 && ref $_[0] eq 'ARRAY' ? [@{$_[0]}] : [@_];

    return $self;
}

sub regular_columns {
    my $self = shift;

    my @primary_key = $self->primary_key;
    my @regular_columns;

    foreach my $column ($self->columns) {
        push @regular_columns, $column
          unless $self->is_in_primary_key($column);
    }

    return @regular_columns;
}

sub primary_key {
    my $self = shift;

    return wantarray ? @{$self->{primary_key}} : $self->{primary_key}->[0]
      unless @_;

    $self->{primary_key} = [];

    my @columns = @_ == 1 && ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;
    $self->add_to_primary_key($_) for @columns;

    return $self;
}

sub add_to_primary_key {
    my $self = shift;
    my $name = shift;

    $self->_check_column($name);

    push @{$self->{primary_key}}, $name;
}

sub unique_keys {
    my $self = shift;

    return $self->{unique_keys} unless @_;

    my @keys = @_;
    foreach my $unique_key (@keys) {
        $unique_key = [$unique_key] unless ref $unique_key eq 'ARRAY';
        $self->add_unique_key($unique_key);
    }

    return $self;
}

sub add_unique_key {
    my $self = shift;

    push @{$self->{unique_keys}}, [];

    my @columns = @_ == 1 && ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;
    $self->add_unique_key_column($_) for @columns;

}

sub add_unique_key_column {
    my $self        = shift;
    my $column_name = shift;

    $self->_check_column($column_name);

    push @{$self->{unique_keys}->[-1]}, $column_name;
}

sub _check_column {
    my $self = shift;
    my $name = shift;

    my $class = $self->class;
    Carp::croak qq/Unknown column '$name' in class $class/
      unless $self->is_column($name);
}

# NOTE: method not in use anywhere riqht now
sub is_primary_key {
    my $self = shift;

    my @possible    = sort @_;
    my @primary_key = sort $self->primary_key;

    return 0 unless @primary_key == @possible;

    while (@primary_key) {
        return 0 unless shift @primary_key eq shift @possible;
    }

    return 1;
}

sub is_in_primary_key {
    my $self = shift;
    my $name = shift;

    return (grep { $name eq $_ } $self->primary_key) ? 1 : 0;
}

# NOTE: method not in use anywhere riqht now
sub is_unique_key {
    my $self = shift;

    my @columns_to_check = @_;

    return 0 unless @{$self->unique_keys};

  OUTER_LOOP: foreach my $unique_key (@{$self->unique_keys}) {

        my @unique_key = sort @$unique_key;
        my @possible   = sort @columns_to_check;

        next OUTER_LOOP unless @unique_key == @possible;

        while (@unique_key) {
            next OUTER_LOOP unless shift @unique_key eq shift @possible;
        }

        return 1;

    }

    return 0;
}

sub is_column {
    my $self = shift;
    my $name = shift;

    my @ok = grep { $name eq $_ } $self->columns;
    return @ok ? 1 : 0;
}

sub is_relationship {
    my $self = shift;
    my $name = shift;

    return exists $self->{relationships}->{$name};
}

sub relationship {
    my $self = shift;
    my $name = shift;

    my $rel = $self->{relationships}->{$name};

    unless ($rel) {
        my $class = $self->class;
        Carp::croak qq/Unknown relationship '$name' in class '$class'/;
    }

    return $rel;
}

sub child_relationships {
    my $self = shift;

    my @rel;
    while (my ($key, $value) = each %{$self->{relationships}}) {
        push @rel, $key
          if $value->is_type(qw/has_one has_many has_and_belongs_to_many/);
    }

    return @rel;
}

sub parent_relationships {
    my $self = shift;

    my @rel;
    while (my ($key, $value) = each %{$self->{relationships}}) {
        push @rel, $key if $value->is_type(qw/belongs_to_one belongs_to/);
    }

    return @rel;
}

sub add_column {
    my $self = shift;
    my $name = shift;

    push @{$self->{columns}}, $name;
}

sub proxy          { shift->_new_relationship('proxy'          => @_) }
sub has_one        { shift->_new_relationship('has_one'        => @_) }
sub belongs_to_one { shift->_new_relationship('belongs_to_one' => @_) }
sub belongs_to     { shift->_new_relationship('belongs_to'     => @_) }
sub has_many       { shift->_new_relationship('has_many'       => @_) }

sub has_and_belongs_to_many {
    shift->_new_relationship('has_and_belongs_to_many' => @_);
}

sub _new_relationship {
    my $self    = shift;
    my $type    = shift;
    my $foreign = shift;

    return $self
      if !ref($foreign) && $self->{relationships}->{$foreign};

    my $class = 'ObjectDB::Relationship::' . camelize($type);
    Class::Load::load_class($class);

    my $args = @_ == 1 ? $_[0] : {@_};

    foreach my $name (@{ref($foreign) ? $foreign : [$foreign]}) {
        my $rel = $class->new(
            name      => $name,
            class     => $self->class,
            namespace => $self->namespace,
            table     => $self->table,
            %$args
        );
        $self->{relationships}->{$name} = $rel;
    }

    return $self;
}

sub _get_parents {
    my $class = shift;
    my @parents;

    no strict 'refs';

    foreach my $sub_class (@{"${class}::ISA"}) {
        last if $sub_class eq 'ObjectDB';

        push @parents, $sub_class, _get_parents($sub_class)
          if $sub_class->isa('ObjectDB');
    }

    return @parents;
}

1;
