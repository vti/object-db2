package ObjectDB::SQL::Select;

use strict;
use warnings;

use base 'ObjectDB::SQL::Base';

sub BUILD {
    my $self = shift;
    $self->{sources} = [] if not exists $self->{sources};
}

sub having   { @_ > 1 ? $_[0]->{having}   = $_[1] : $_[0]->{having} }
sub group_by { @_ > 1 ? $_[0]->{group_by} = $_[1] : $_[0]->{group_by} }
sub sources { $_[0]->{sources} }

use ObjectDB::SQL::Condition;
use ObjectDB::SQL::Utils qw/escape prepare_column/;

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{_columns} ||= [];
    $self->{_source} = $self->{sources}->[0];

    return $self;
}

sub first_source {
    my $self = shift;

    my $name = $self->{sources}->[0];
    $self->source($name);
}

sub source {
    my $self = shift;
    my ($source) = @_;

    return $self if $self->switch_to_source($source);

    # Create a new source
    $self->add_source($source);

    return $self;
}

sub switch_to_source {
    my $self = shift;

    if (my $s = $self->has_source(@_)) {
        $self->{_source} = $s;
        return $self;
    }
    return;
}

sub has_source {
    my $self = shift;
    my ($source) = @_;

    $source = {name => $source} unless ref $source eq 'HASH';

    my $name = $source->{name};
    my $as   = $source->{as};

    # Source already exists
    for (my $i = 0; $i < @{$self->sources}; $i++) {
        my $s = $self->sources->[$i];

        if ($as) {
            if ($as eq $s->{name} || ($s->{as} && $s->{as} eq $as)) {
                return $s;
            }
        }
        elsif ($name eq $s->{name}) {
            return $s;
        }
    }
    return;
}

sub add_source {
    my $self = shift;
    my ($source) = @_;

    # Normalize
    $source = {name => $source} unless ref $source eq 'HASH';

    $source->{columns} ||= [];

    push @{$self->sources}, $source;
    $self->{_source} = $self->sources->[-1];

    return $self->{_source};
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
            $col = $column->{as} || $column->{name};
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
                        my $prefix =
                            $need_prefix
                          ? $source->{as} || $source->{name}
                          : undef;
                        $col_full = prepare_column($col_full, $prefix);
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
    $self->bind($self->where->bind);

    if (my $group_by = $self->{group_by}) {
        $group_by = prepare_column($group_by, $default_prefix);
        $query .= ' GROUP BY ' . $group_by;
    }

    # TO DO: REWRITE NECESSARY
    if ($self->{having} && ref $self->{having} eq 'SCALAR') {
        $query .= ' HAVING ' . ${$self->{having}} if $self->{having};
    }
    else {
        $query .= ' HAVING ' . escape($self->{having}) if $self->{having};
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

            $col = prepare_column($col, $default_prefix);

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
    my $self           = shift;
    my $default_prefix = shift;

    my $string = "";

    my $first = 1;
    foreach my $source (@{$self->sources}) {
        $string .= ', ' unless $first || $source->{join};

        $string .= ' ' . uc $source->{join} . ' JOIN ' if $source->{join};

        if ($source->{sub_req}) {
            $string .= '(' . $source->{sub_req} . ')';
        }
        else {
            $string .= escape($source->{name});
        }

        if ($source->{as}) {
            $string .= ' AS ' . escape($source->{as});
        }

        if ($source->{constraint}) {
            $string .= ' ON ';

            my $cond = ObjectDB::SQL::Condition->new;
            $cond->cond($source->{constraint});
            $cond->prefix($default_prefix);
            $cond->driver($self->driver);

            $string .= $cond->build;

            $self->bind($cond->bind);

        }
        $first = 0;
    }

    return $string;
}

1;
