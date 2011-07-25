package ObjectDB::Columns;

use strict;
use warnings;

use base 'ObjectDB::Base';

sub BUILD {
    my $self = shift;

    $self->{columns} ||= {};
}

sub is_empty { keys(%{$_[0]->{columns}}) == 0 }

sub is_modified { $_[0]->{is_modified} || 0 }
sub schema { $_[0]->{schema} }

sub not_modified { $_[0]->{is_modified} = 0 }

sub set {
    my $self = shift;
    my ($name, $value) = @_;

    if (defined $self->{columns}->{$name} && defined $value) {
        $self->{is_modified} = 1
          if $self->{columns}->{$name} ne $value;
    }
    elsif (defined $self->{columns}->{$name} || defined $value) {
        $self->{is_modified} = 1;
    }

    $self->{columns}->{$name} = $value;

    return $self;
}

sub get {
    my $self = shift;
    my ($name) = @_;

    return $self->{columns}->{$name};
}

sub names {
    my $self = shift;

    return keys %{$self->{columns}};
}

sub values {
    my $self = shift;

    return values %{$self->{columns}};
}

sub regular_columns {
    my $self = shift;

    my @columns;

    foreach my $column ($self->schema->regular_columns) {
        push @columns, $column if exists $self->{columns}->{$column};
    }

    return @columns;
}

sub pk_columns {
    my $self = shift;

    my @primary_key = $self->schema->primary_key;
    foreach my $column (@primary_key) {
        return () unless defined $self->{columns}->{$column};
    }

    return @primary_key;
}

sub uk_columns {
    my $self = shift;

    my $unique_keys = $self->schema->unique_keys;

  OUTER_LOOP: foreach my $unique_key (@$unique_keys) {

        foreach my $column (@$unique_key) {
            next OUTER_LOOP unless exists $self->{columns}->{$column};
        }

        return @$unique_key;

    }

    return ();
}

sub pk_or_uk_columns {
    my $self = shift;

    my @columns = $self->pk_columns;

    return @columns if @columns;

    push @columns, $self->uk_columns;

    return @columns;
}

sub have_pk_or_ai_columns {
    my $self = shift;

    return 1 if $self->pk_columns;

    my @pk = $self->schema->primary_key;
    return 1 if @pk == 1 && $self->schema->auto_increment eq $pk[0];

    return 0;
}

1;
