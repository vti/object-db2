package ObjectDB::Relationship::Base;

use strict;
use warnings;

use base 'ObjectDB::Base';

use Class::Load ();

use ObjectDB::Utils qw/camelize decamelize class_to_table plural_to_single/;

sub BUILD {
    my $self = shift;

    $self->{map}       = {} unless exists $self->{map};
    $self->{with}      = [] unless exists $self->{with};
    $self->{where}     = [] unless exists $self->{where};
    $self->{join_args} = [] unless exists $self->{join_args};
    $self->{foreign_class_to_cols} = []
      unless exists $self->{foreign_class_to_cols};
    $self->{foreign_class_from_cols} = []
      unless exists $self->{foreign_class_from_cols};
    $self->{map_to_cols}   = [] unless exists $self->{map_to_cols};
    $self->{map_from_cols} = [] unless exists $self->{map_from_cols};
    $self->{is_built}      = 0  unless exists $self->{is_built};
}

sub name { $_[0]->{name} }

sub foreign_class {
    @_ > 1 ? $_[0]->{foreign_class} = $_[1] : $_[0]->{foreign_class};
}

sub foreign_table {
    @_ > 1 ? $_[0]->{foreign_table} = $_[1] : $_[0]->{foreign_table};
}

sub namespace { $_[0]->{namespace} }

sub map { @_ > 1 ? $_[0]->{map} = $_[1] : $_[0]->{map} }

sub with { @_ > 1 ? $_[0]->{with} = $_[1] : $_[0]->{with} }

sub where { @_ > 1 ? $_[0]->{where} = $_[1] : $_[0]->{where} }

sub join_args { $_[0]->{join_args} }

sub foreign_class_to_cols { $_[0]->{foreign_class_to_cols} }

sub foreign_class_from_cols { $_[0]->{foreign_class_from_cols} }

sub map_to_cols { $_[0]->{map_to_cols} }

sub map_from_cols { $_[0]->{map_from_cols} }

sub is_built { @_ > 1 ? $_[0]->{is_built} = $_[1] : $_[0]->{is_built} }

sub type { decamelize((split '::' => ref(shift))[-1]) }

sub class {
    my $self = shift;

    my $class = $self->{class};

    Class::Load::load_class($class);

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

    return $self if $self->is_built;

    $self->_detect_and_load_foreign_class;

    $self->_detect_foreign_table(@_);

    $self->_detect_column_mapping(@_);

    $self->is_built(1);

    # Now build other schemas (and other relationships) AFTER
    # current rel is flaged as build
    $self->foreign_class->schema->build(@_) if $self->foreign_class;

    # TO DO: custom map class (non auto-generated)
    # $self->map_class->schema->build(@_) if $self->can('map_class');

    # Always build relationships from map_class to foreign classes
    $self->build_map_class_rels(@_) if $self->can('map_class');

    return $self;
}

sub build_map_class_rels {
    my $self = shift;

    # Build relationships of map class
    $self->map_schema->relationships->{$self->map_from}->build(@_);
    $self->map_schema->relationships->{$self->map_to}->build(@_);

    # Create mapping cols accessors for main class
    # ARRAY TO ALWAY GET THE SAME ORDER
    while (my ($to, $from) =
        each %{$self->map_schema->relationships->{$self->map_from}->map})
    {
        push @{$self->map_from_cols}, $from;
        push @{$self->map_to_cols},   $to;
    }

    # Create mapping cols accessors for foreign class
    while (my ($from, $to) =
        each %{$self->map_schema->relationships->{$self->map_to}->map})
    {
        push @{$self->foreign_class_from_cols}, $from;
        push @{$self->foreign_class_to_cols},   $to;
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

    Class::Load::load_class($self->foreign_class);

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
