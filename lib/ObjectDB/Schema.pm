package ObjectDB::Schema;

use strict;
use warnings;

use base 'ObjectDB::Base';

__PACKAGE__->attr([qw/table class auto_increment namespace/]);
__PACKAGE__->attr(relationships => sub { {} });
__PACKAGE__->attr(is_built => 0);

require Carp;
use ObjectDB::Loader;
use ObjectDB::SchemaDiscoverer;
use ObjectDB::Utils qw/camelize class_to_table/;

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{columns}     ||= [];
    $self->{primary_key} ||= [];
    $self->{unique_keys} ||= [];

    $self->table(class_to_table($self->class)) unless $self->table;

    return $self;
}

sub build {
    my $self = shift;

    return if $self->is_built;

    $self->auto_discover(@_) unless $self->columns;

    # as related schemas are be built during the next step, which might
    # try to build the current schema again, flag current schmema as built
    # before build_relationships
    $self->is_built(1);

    $self->build_relationships(@_);

    return $self;
}

sub auto_discover {
    my $self = shift;
    my $conn = shift;

    Carp::croak qq/Connector is required for automatic column discovery/
      unless $conn;

    $conn->run(
        sub {
            my $dbh        = shift;
            my $discoverer = ObjectDB::SchemaDiscoverer->build(
                driver => $dbh->{'Driver'}->{'Name'},
                table  => $self->table
            );

            $discoverer->discover($dbh);

            $self->add_column($_) for @{$discoverer->columns};

            $self->add_to_primary_key($_) for @{$discoverer->primary_key};

            $self->add_unique_key($_) for @{$discoverer->unique_keys};

            $self->auto_increment($discoverer->auto_increment)
              if $discoverer->auto_increment;
        }
    );
}

sub build_relationships {
    my $self = shift;

    while (my ($key, $value) = each %{$self->relationships}) {
        $value->build(@_);
    }
}

sub columns { @{shift->{columns} || []} }

sub primary_key {
    my $self = shift;

    return wantarray ? @{$self->{primary_key}} : $self->{primary_key}->[0];
}

sub add_to_primary_key {
    my $self = shift;
    my $name = shift;

    push @{$self->{primary_key}}, $name;
}

sub unique_keys {
    my $self = shift;

    return wantarray ? @{$self->{unique_keys}} : $self->{unique_keys}->[0];
}

sub add_unique_key {
    my $self = shift;
    my $name = shift;

    push @{$self->{unique_keys}}, $name;
}

sub is_primary_key {
    my $self = shift;
    my $name = shift;

    my @ok = grep { $name eq $_ } $self->primary_key;
    return @ok ? 1 : 0;
}

sub is_unique_key {
    my $self = shift;
    my $name = shift;

    my @ok = grep { $name eq $_ } $self->unique_keys;
    return @ok ? 1 : 0;
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

    return exists $self->relationships->{$name};
}

sub relationship {
    my $self = shift;
    my $name = shift;

    my $rel = $self->relationships->{$name};

    unless ($rel) {
        my $class = $self->class;
        Carp::croak qq/Unknown relationship '$name' in class '$class'/;
    }

    return $rel;
}

sub child_relationships {
    my $self = shift;

    my @rel;
    while (my ($key, $value) = each %{$self->relationships}) {
        push @rel, $key
          if $value->is_type(qw/has_one has_many has_and_belongs_to_many/);
    }

    return @rel;
}

sub parent_relationships {
    my $self = shift;

    my @rel;
    while (my ($key, $value) = each %{$self->relationships}) {
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
      if !ref($foreign) && $self->relationships->{$foreign};

    my $class = 'ObjectDB::Relationship::' . camelize($type);
    ObjectDB::Loader->load($class);

    my $args = @_ == 1 ? $_[0] : {@_};

    foreach my $name (@{ref($foreign) ? $foreign : [$foreign]}) {
        my $rel = $class->new(
            name      => $name,
            class     => $self->class,
            namespace => $self->namespace,
            table     => $self->table,
            %$args
        );
        $self->relationships->{$name} = $rel;
    }

    return $self;
}

1;
