package ObjectDB::SQL::Select;

use strict;
use warnings;

use base 'ObjectDB::SQL::Base';
use ObjectDB::SQL::Condition;

__PACKAGE__->attr([qw/group_by having/]);
__PACKAGE__->attr([qw/sources/] => sub {[]});

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{_columns} ||= [];
    $self->{_source} = $self->{sources}->[0];

    return $self;
}

sub prepare_column {
    my $class   = shift;
    my $column  = shift;
    my $default = shift;

    # Prefixed
    if ($column =~ s/^(\w+)\.//) {
        $column = $class->escape($1) . '.' . $class->escape($column);
    }
    # Default prefix
    elsif ($default) {
        $column =
            $class->escape($default) . '.'
          . $class->escape($column);
    }
    # No Prefix
    else {
        $column = $class->escape($column);
    }
    return $column;

}

sub first_source {
    my $self = shift;

    my $name = $self->{sources}->[0];
    $self->source($name);
}

sub source {
    my $self = shift;
    my ($source) = @_;

    $source = {name => $source} unless ref $source eq 'HASH';

    $source->{columns} ||= [];

    if (my $as = $source->{as}) {

        # Source already exists
        for (my $i = 0; $i < @{$self->sources}; $i++) {
            my $s = $self->sources->[$i];

            if ($source->{as} eq $s->{name}
                || ($s->{as} && $s->{as} eq $source->{as}))
            {
                $self->{_source} = $self->sources->[$i];
                return $self;
            }
        }
    }
    else {

        # Source already exists
        for (my $i = 0; $i < @{$self->sources}; $i++) {
            if ($source->{name} eq $self->sources->[$i]->{name}) {
                $self->{_source} = $self->sources->[$i];
                return $self;
            }
        }
    }

    # Create a new source
    push @{$self->sources}, $source;
    $self->{_source} = $self->sources->[-1];

    return $self;
}

sub columns {
    my $self = shift;

    if (@_) {
        die 'first define source' unless @{$self->sources};

        $self->{_source}->{columns} ||= [];

        # Only add the new columns
        my @columns;
        my @new_columns = ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;
        foreach my $col (@new_columns) {
            push @columns, $col
              unless grep { $col eq $_ } @{$self->{_source}->{columns}};
        }

        push @{$self->{_source}->{columns}}, @columns if @columns;

        return $self;
    }

    my @column_names = ();

    foreach my $column (@{$self->sources->[0]->{columns}}) {
        my $col;
        if (ref $column eq 'SCALAR') {
            $col = $$column;
        }
        elsif (ref $column eq 'HASH') {
            $col = $column->{as};
        }
        else {
            $col = $column;
        }

        push @column_names, $col;
    }

    return @column_names;
}

sub to_string {
    my $self = shift;

    my $query = "";
    $self->{bind} = [];

    $query .= 'SELECT ';

    my $need_prefix = @{$self->sources} > 1;
    my $first       = 1;
    foreach my $source (@{$self->sources}) {
        if (@{$source->{columns}}) {
            $query .= ', ' unless $first;

            my @columns;
            foreach my $col (@{$source->{columns}}) {
                if (ref $col eq 'SCALAR') {
                    push @columns, $$col;
                }
                else {
                    my $col_full = $col;

                    my $as;
                    if (ref $col_full eq 'HASH') {
                        $as       = $col_full->{as};
                        $col_full = $col_full->{name};
                    }

                    if (ref $col_full eq 'SCALAR') {
                        $col_full = $$col_full;
                    }
                    else {
                        my $prefix = $need_prefix ? $source->{as}
                          || $source->{name} : undef;
                        $col_full =
                          $self->prepare_column($col_full,$prefix);
                    }

                    push @columns, $as ? "$col_full AS $as" : $col_full;
                }
            }

            $query .= join(', ', @columns);

            $first = 0;
        }
    }

    $query .= ' FROM ';

    my $default_prefix;
    if ($need_prefix) {
        $default_prefix = $self->sources->[0]->{name};
    }

    $query .= $self->sources_to_string($default_prefix);


    $self->where->prefix($default_prefix) if $default_prefix;
    $query .= $self->where;
    $self->bind( $self->where->bind );

    if (my $group_by = $self->group_by) {
        $group_by = $self->prepare_column($group_by,$default_prefix);
        $query .= ' GROUP BY ' . $group_by;
    }

    # TO DO: REWRITE NECESSARY
    if ( $self->having && ref $self->having eq 'SCALAR'){
        $query .= ' HAVING ' . ${$self->having} if $self->having;
    }
    else {
        $query .= ' HAVING ' . $self->escape( $self->having) if $self->having;
    }

    if (my $order_by = $self->order_by) {
        my @cols = split(/\s*,\s*/, $order_by);

        $query .= ' ORDER BY ';

        my $first = 1;
        foreach my $col (@cols) {
            my $order;
            if ($col =~ s/\s+(ASC|DESC)\s*//i) {
                $order = $1;
            }

            $col = $self->prepare_column($col,$default_prefix);

            $query .= ', ' unless $first;

            $query .= $col;
            $query .= ' ' . $order if $order;

            $first = 0;
        }
    }

    $query .= ' LIMIT ' . $self->limit if $self->limit;

    $query .= ' OFFSET ' . $self->offset if $self->offset;

    return $query;
}

sub sources_to_string {
    my $self = shift;
    my $default_prefix = shift;

    my $string = "";

    my $first = 1;
    foreach my $source (@{$self->sources}) {
        $string .= ', ' unless $first || $source->{join};

        $string .= ' ' . uc $source->{join} . ' JOIN ' if $source->{join};

        if ( $source->{sub_req} ){
            $string .= '('.$source->{sub_req}.')';
        }
        else {
            $string .= $self->escape($source->{name});
        }

        if ($source->{as}) {
            $string .= ' AS ' . $self->escape($source->{as});
        }

        if ($source->{constraint}) {
            $string .= ' ON ';

            my $condition = ObjectDB::SQL::Condition->new;

            $string .=
              $condition->_build({
                condition => $source->{constraint},
                prefix    => $default_prefix,
                driver    => $self->driver
               });

            $self->bind( $condition->bind );

        }
        $first = 0;
    }

    return $string;
}

1;
