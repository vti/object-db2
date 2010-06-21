package ObjectDB::Schema;

use strict;
use warnings;

use base 'ObjectDB::Base';

__PACKAGE__->attr(driver => 'sqlite');
__PACKAGE__->attr([qw/table class auto_increment/]);
__PACKAGE__->attr(columns       => sub { [] });
__PACKAGE__->attr(primary_keys  => sub { [] });
__PACKAGE__->attr(unique_keys   => sub { [] });
__PACKAGE__->attr(relationships => sub { {} });
__PACKAGE__->attr(is_built => 0);

require Carp;
use ObjectDB::Loader;
use ObjectDB::Util;
use Scalar::Util qw/weaken isweak/;

sub new {
    my $self = shift->SUPER::new(@_);

    $self->table(ObjectDB::Util->class_to_table($self->class)) unless $self->table;

    return $self;
}

sub build {
    my $self = shift;

    return if $self->is_built;

    $self->auto_discover(@_) unless @{$self->columns};

    while (my ($key, $value) = each %{$self->relationships}) {
        $value->build(@_);
    }

    $self->is_built(1);

    return $self;
}

sub auto_discover {
    my $self = shift;
    my $dbh = shift;

    Carp::croak qq/dbh is required for automatic column discovery/
      unless $dbh;

    local $dbh->{'FetchHashKeyName'} = 'NAME';

    my $sth = $dbh->table_info(undef, 'main', $self->table);
    my $sql;
    while (my $table_info = $sth->fetchrow_hashref) {
        $sql = $table_info->{sqlite_sql};
        last if $sql;
    }

    if ($sql) {
        if (my ($unique) = ($sql =~ m/UNIQUE\((.*?)\)/)) {
            my @uk = split ',' => $unique;
            foreach my $uk (@uk) {
                $self->unique_key($self->_unquote($uk));
            }
        }

        foreach my $part (split '\n' => $sql) {
            if ($part =~ m/AUTO_?INCREMENT/i) {
                if ($part =~ m/^\s*`(.*?)`/) {
                    $self->auto_increment($1);
                }
            }
        }
    }

    $sth = $dbh->column_info(undef, 'main', $self->table, '%');
    while (my $col_info = $sth->fetchrow_hashref) {
        $self->column($self->_unquote($col_info->{COLUMN_NAME}));
    }

    $sth = $dbh->primary_key_info(undef, 'main', $self->table);
    while (my $col_info = $sth->fetchrow_hashref) {
        $self->primary_key($self->_unquote($col_info->{COLUMN_NAME}));
    }
}

sub primary_key {
    my $self = shift;
    my $name = shift;

    push @{$self->primary_keys}, $name;
}

sub unique_key {
    my $self = shift;
    my $name = shift;

    push @{$self->unique_keys}, $name;
}

sub is_primary_key {
    my $self = shift;
    my $name = shift;

    my @ok = grep { $name eq $_ } @{$self->primary_keys};
    return @ok ? 1 : 0;
}

sub is_unique_key {
    my $self = shift;
    my $name = shift;

    my @ok = grep { $name eq $_ } @{$self->unique_keys};
    return @ok ? 1 : 0;
}

sub is_column {
    my $self = shift;
    my $name = shift;

    my @ok = grep { $name eq $_ } @{$self->columns};
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
    Carp::croak qq/Unknown relationship '$name'/ unless $rel;

    return $rel;
}

sub child_relationships {
    my $self = shift;

    my @rel;
    while (my ($key, $value) = each %{$self->relationships}) {
        push @rel, $key if $value->type =~ m/^(?:has_one|has_many)$/;
    }

    return @rel;
}

sub parent_relationships {
    my $self = shift;

    my @rel;
    while (my ($key, $value) = each %{$self->relationships}) {
        push @rel, $key if $value->type =~ m/^(?:belongs_to_one|belongs_to)$/;
    }

    return @rel;
}

sub column {
    my $self = shift;
    my $name = shift;

    push @{$self->columns}, $name;
}

sub has_one        { shift->_new_relationship('has_one'        => @_) }
sub belongs_to_one { shift->_new_relationship('belongs_to_one' => @_) }
sub belongs_to     { shift->_new_relationship('belongs_to'     => @_) }
sub has_many       { shift->_new_relationship('has_many'       => @_) }

sub has_and_belongs_to_many {
    shift->_new_relationship('has_and_belongs_to_many' => @_);
}

sub _new_relationship {
    my $self = shift;
    my $type = shift;
    my $name = shift;

    my $class = 'ObjectDB::Relationship::' . ObjectDB::Util->camelize($type);
    ObjectDB::Loader->load($class);

    my $rel = $class->new(name => $name, class => $self->class, @_);

    $self->relationships->{$name} = $rel;

    return $self;
}

sub _unquote {
    my $self  = shift;
    my $value = shift;

    $value =~ s/^\`//;
    $value =~ s/\`$//;

    return $value;
}

1;
