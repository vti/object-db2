package ObjectDB::SQL::Select;

use strict;
use warnings;

use base 'ObjectDB::SQL::Base';

__PACKAGE__->attr([qw/group_by having order_by limit offset where_logic/]);
__PACKAGE__->attr([qw/sources/] => sub {[]});

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{_columns} ||= [];
    $self->{_source} = $self->{sources}->[0];
    $self->{where} ||= [];

    return $self;
}

sub where {
    my $self = shift;

    if (@_) {
        my @params;

        if (@_ == 1) {
            push @{$self->{where}}, ref $_[0] eq 'ARRAY' ? @{$_[0]} : $_[0]
              if defined $_[0];
        }
        else {
            push @{$self->{where}}, @_;
        }

        return $self;
    }

    return $self->{where};
}

sub _columns { @_ > 1 ? $_[0]->{_columns} = $_[1] : $_[0]->{_columns} }

sub with {
    my $self = shift;

    if (@_) {
        $self->{with} ||= [];
        push @{$self->{with}}, ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;
        return $self;
    }

    return $self->{with};
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
                        if ($col_full =~ s/^(\w+)\.//) {
                            $col_full = $self->escape($1) . '.' . $self->escape($col_full);
                        }
                        elsif ($need_prefix) {
                            $col_full =
                              $self->escape($source->{as} || $source->{name})
                              . '.'
                              . $self->escape($col_full);
                        }
                        else {
                            $col_full = $self->escape($col_full);
                        }
                    }

                    push @columns, $as ? "$col_full AS $as" : $col_full;
                }
            }

            $query .= join(', ', @columns);

            $first = 0;
        }
    }

    $query .= ' FROM ';

    $query .= $self->sources_to_string;

    my $default_prefix;
    if ($need_prefix) {
        $default_prefix = $self->sources->[0]->{name};
    }

    if (my $where = $self->where) {
        if (ref $where eq 'ARRAY' && @$where || ref $where ne 'ARRAY') {
            $query .= ' WHERE ';
            $query .= $self->_where_to_string($self->where, $default_prefix);
        }
    }

    if (my $group_by = $self->group_by) {
        if ($default_prefix) {
            if ($group_by =~ s/^(\w+)\.//) {
                $group_by = $self->escape($1) . '.' . $self->escape($group_by);
            }
            else {
                $group_by =
                    $self->escape($default_prefix) . '.'
                  . $self->escape($group_by);
            }
        }
        else {
            $group_by = $self->escape($group_by);
        }

        $query .= ' GROUP BY ' . $group_by;
    }

    $query .= ' HAVING ' . $self->escape($self->having) if $self->having;

    if (my $order_by = $self->order_by) {
        my @cols = split(/\s*,\s*/, $order_by);

        $query .= ' ORDER BY ';

        my $first = 1;
        foreach my $col (@cols) {
            my $order;
            if ($col =~ s/\s+(ASC|DESC)\s*//i) {
                $order = $1;
            }

            if ($col =~ s/^(\w+)\.//) {
                $col = $self->escape($1) . '.' . $self->escape($col);
            }
            elsif ($default_prefix) {
                $col = $self->escape($default_prefix) . '.' .  $self->escape($col);
            }
            else {
                $col = $self->escape($col);
            }

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

    my $string = "";

    my $first = 1;
    foreach my $source (@{$self->sources}) {
        $string .= ', ' unless $first || $source->{join};

        $string .= ' ' . uc $source->{join} . ' JOIN ' if $source->{join};

        $string .= $self->escape($source->{name});

        if ($source->{as}) {
            $string .= ' AS ' . $self->escape($source->{as});
        }

        if ($source->{constraint}) {
            $string .= ' ON ';

            my $count = 0;
            while (my ($key, $value) =
                @{$source->{constraint}}[$count, $count + 1])
            {
                last unless $key;

                $string .= ' AND ' unless $count == 0;

                my $from = $key;
                my $to   = $value;

                if ($from =~ s/^(\w+)\.//) {
                    $from = $self->escape($1) . '.' . $self->escape($from);
                }
                else {
                    $from = $self->escape($from);
                }

                if ($to =~ s/^(\w+)\.//) {
                    $to = $self->escape($1) . '.' . $self->escape($to);
                }
                else {
                    $to = "'$to'";
                }

                $string .= $from . ' = ' . $to;

                $count += 2;
            }
        }

        $first = 0;
    }

    return $string;
}

1;
