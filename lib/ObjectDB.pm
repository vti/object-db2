package ObjectDB;

use strict;
use warnings;

use base 'ObjectDB::Base';

use constant DEBUG => $ENV{OBJECTDB_DEBUG} || 0;

our $VERSION = '0.990201';

require Carp;
use ObjectDB::Columns;
use ObjectDB::Related;
use ObjectDB::Counter;
use ObjectDB::Creator;
use ObjectDB::Finder;
use ObjectDB::Remover;
use ObjectDB::Schema;
use ObjectDB::Updater;
use ObjectDB::Utils 'single_to_plural';
use Scalar::Util qw(blessed);

sub BUILD {
    my $self = shift;

    $self->schema->build($self->dbh);

    $self->{columns} ||= ObjectDB::Columns->new(schema => $self->schema);
    $self->{related} ||= ObjectDB::Related->new;
}

sub is_modified { $_[0]->{columns}->is_modified }
sub is_empty    { $_[0]->{columns}->is_empty }
sub is_in_db    { $_[0]->{is_in_db} }

sub plural_class_name {
    my $class = shift;
    $class = ref $class ? ref $class : $class;

    return single_to_plural($class);
}

sub dbh {
    my $self = shift;

    return $self->{dbh} = $_[0] if @_;

    Carp::croak(qq/dbh object is required/) unless $self->{dbh};

    return $self->{dbh};
}

sub schema {
    my $class = shift;
    my $table = shift;

    $table ||= '';

    my $class_name = ref $class ? ref $class : $class;

    return $ObjectDB::Schema::objects{$class_name} ||= ObjectDB::Schema->new(
        table     => $table,
        class     => $class_name,
        namespace => $class->namespace,
        @_
    );
}

sub namespace {

    # Overwrite this method in subclass to allow use of short class names
    # e.g. when defining foreign_class in relationship
    # e.g. sub namespace { 'My::Schema::Path' }
    return undef;
}

sub objectdb_lazy {

    # Overwrite this method in CGI environments
    # to load related classes only if needed
    # sub objectdb_lazy {1;}
    # or set $ENV{OBJECTDB_LAZY} to 1

    return $ENV{OBJECTDB_LAZY} || undef;
}

sub id {
    my $self = shift;

    Carp::croak 'No primary key defined in class ' . ref $self
        unless $self->schema->primary_key;

    if (@_) {
        for my $column ($self->schema->primary_key) {
            $self->column($column => shift @_);
        }
        return $self;
    }

    my @values = map { $self->column($_) } $self->schema->primary_key;

    return wantarray ? @values : $values[0];
}

sub column {
    my $self = shift;
    my ($name, $value) = @_;

    if (@_ == 1) {
        return $self->{columns}->get($name);
    }

    $self->{columns}->set($name, $value);

    return $self;
}

sub set_columns {
    my $self   = shift;
    my %params = @_;

    while (my ($key, $value) = each %params) {
        if ($self->schema->is_column($key)) {
            $self->{columns}->set($key => $value);
        }
        elsif ($self->schema->is_relationship($key)) {
            $self->{related}->set($key => $value);
        }
        else {
            Carp::croak qq/Unknown column '$key' in table: /
              . ref($self)->schema->table
              . qq/ or unknown relationship in class: /
              . ref($self);
        }
    }

    return $self;
}

sub virtual_column {
    my $self = shift;

    $self->{virtual_columns} ||= {};

    if (@_ == 1) {
        return defined $_[0] ? $self->{virtual_columns}->{$_[0]} : undef;
    }
    elsif (@_ >= 2) {
        my %columns = @_;
        while (my ($key, $value) = each %columns) {
            $self->{virtual_columns}->{$key} = $value;
        }
    }

    return $self;
}

sub virtual_columns {
    my $self = shift;

    $self->{virtual_columns} ||= {};

    my @columns;

    foreach my $column (keys %{$self->{virtual_columns}}) {
        push @columns, $column;
    }

    return @columns;
}

sub related {
    my $self = shift;
    my ($name) = @_;

    my $rel = $self->schema->relationship($name);
    $rel->build($self->dbh);

    my $related = $self->{related}->get($name);

    return $related if $related;

    return if defined $related && $related == 0;

    # Allow tests to make sure that checked data was prefetched
    die "OBJECTDB_FORCE_PREFETCH: data has to be prefetched: '$name'"
      if $ENV{OBJECTDB_FORCE_PREFETCH};

    if ($rel->is_type(qw/has_one belongs_to/)) {
        $self->{related}
          ->set($name => $self->find_related($name, first => 1));
        return $self->{related}->get($name);
    }

    my @objects = $self->find_related($name);
    $self->{related}->push($name, @objects);
    return wantarray ? @objects : \@objects;
}

sub count {
    my $self = shift;

    return $self->_counter->count(@_);
}

sub create {
    my $self = shift;

    $self->_creator->create(@_);

    $self->{is_in_db} = 1;

    return $self;
}

sub create_related {
    my $self = shift;

    return $self->_creator->create_related(@_);
}

sub find {
    my $self = shift;

    return $self->_finder->find(@_);
}

sub find_related {
    my $self = shift;

    return $self->_finder->find_related(@_);
}

sub find_or_create {
    my $self   = shift;
    my %params = @_;

    my @where;
    while (my ($key, $value) = each %params) {
        push @where, ($key, $value)
          unless $self->schema->is_relationship($key);
    }

    my $find = $self->find(where => [@where], single => 1);
    return $find if $find;

    return $self->set_columns(%params)->create;
}

sub update_column {
    my $self = shift;

    $self->column(@_);

    return $self->update;
}

sub update {
    my $self = shift;

    my $rv = $self->_updater->update(@_);

    $self->{is_in_db} = 1;

    return blessed($rv) ? $self : $rv;
}

sub delete {
    my $self = shift;

    my $rv = $self->_remover->delete(@_);

    $self->{is_in_db} = 0;

    return blessed($rv) ? $self : $rv;
}

sub delete_related {
    my $self = shift;

    return $self->_remover->delete_related(@_);
}

sub to_hash {
    my $self = shift;

    my $hash = {};
    foreach my $key ($self->{columns}->names) {
        $hash->{$key} = $self->column($key);
    }

    foreach my $key ($self->virtual_columns) {
        $hash->{$key} = $self->virtual_column($key);
    }

    foreach my $name ($self->{related}->names) {
        my $rel = $self->{related}->get($name);

        Carp::croak qw/Unknown '$name' relationship/ unless $rel;

        if (ref $rel eq 'ARRAY') {
            $hash->{$name} = [];
            foreach my $r (@$rel) {
                push @{$hash->{$name}}, $r->to_hash;
            }
        }
        else {
            $hash->{$name} = $rel->to_hash;
        }
    }

    return $hash;
}

sub _counter { $_[0]->_build('counter') }
sub _creator { $_[0]->_build('creator') }
sub _finder  { $_[0]->_build('finder') }
sub _remover { $_[0]->_build('remover') }
sub _updater { $_[0]->_build('updater') }

sub _build {
    my $self = shift;
    my ($name) = @_;

    $self->{"_$name"} ||= do {
        my $class_name = 'ObjectDB::' . ucfirst($name);

        $class_name->new(
            namespace => $self->namespace,
            dbh       => $self->dbh,
            schema    => $self->schema,
            columns   => $self->{columns},
            related   => $self->{related}
        );
    };

    return $self->{"_$name"};
}

1;
