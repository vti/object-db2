package ObjectDB::Table;

use strict;
use warnings;

use base 'ObjectDB::Base';

use constant DEBUG => $ENV{OBJECTDB_DEBUG} || 0;

use ObjectDB::Iterator;

sub BUILD {
    my $self = shift;

    die 'class is required' unless $self->{class};
}

sub schema {
    my $self = shift;

    my $schema = $self->{class}->schema;
    $schema->build($self->dbh);

    return $schema;
}

sub dbh {
    my $self = shift;

    return $self->{dbh};
}

sub find {
    my $self   = shift;
    my %params = @_;

    my $single = $params{first} || $params{single} ? 1 : 0;

    my $dbh = $self->dbh;

    my $main = {};

    my $sql = ObjectDB::SQL::Select->new(driver => $self->dbh->{'Driver'}->{'Name'});
    $sql->source($self->schema->table);

    my $with = $self->_normalize_with($params{with});

    my $subreqs = $self->_resolve_with(
        main => $main,
        with => $with,
        sql  => $sql
    );

    # Resolve columns
    $main->{columns} = $self->_resolve_columns(
        {   schema  => $self->schema,
            columns => $params{columns},
            _mapping_columns =>
              [@{$main->{_mapping_columns} || []}, @{$params{map_to} || []}]
        }
    );

    $sql->source($self->schema->table);    ### switch back to main source
    $sql->columns([@{$main->{columns}}]);

    if (defined(my $id = delete $params{id})) {
        $self->_resolve_id($id, $sql);
        $single = 1;
    }
    elsif (my $where = $params{where}) {
        $self->_resolve_where(where => $where, sql => $sql);
    }

    $sql->limit($params{limit}) if $params{limit};
    $sql->limit(1) if $single;

    $sql->offset($params{offset}) if $params{offset} && $sql->limit;

    # FIXME
    if (defined $params{page}) {
        $params{page} = int($params{page});
        $params{page_size} = int($params{page_size} || 10);
        $params{page} = $params{page} > 0 ? $params{page} : 1;
        $params{page_size} = $params{page_size} > 0 ? $params{page_size} : 10;
        $sql->limit($params{page_size});
        $sql->offset(($params{page} - 1) * $params{page_size});
    }

    $sql->order_by($params{order_by}) if $params{order_by};
    $sql->group_by($params{group_by}) if $params{group_by};

    my $wantarray = wantarray;

    # TODO txn
    warn "$sql" if $ENV{OBJECTDB_DEBUG};
    my $sth = $dbh->prepare("$sql");
    return unless $sth;

    my $rv = $sth->execute(@{$sql->bind});
    die 'execute failed' unless $rv;

    if (!$wantarray && !$single) {
        return ObjectDB::Iterator->new(
            cb => sub {
                my @row = $sth->fetchrow_array;
                return unless @row;

                return $self->_row_to_object(
                    row  => [@row],
                    sql  => $sql,
                    with => $with
                );
            }
        );
    }

    my $rows = $sth->fetchall_arrayref;
    return unless $rows && @$rows;

    my @result;

    # Prepare column inflation
    my $inflation_method =
      $self->_inflate_columns($self->schema->class, $params{inflate});

  OUTER_LOOP: foreach my $row (@$rows) {
        my $object = $self->_row_to_object(
            row     => $row,
            sql     => $sql,
            with    => $with,
            inflate => $params{inflate}
        );

        # Column inflation
        $object->$inflation_method if $inflation_method;

        push @result, $object;
    }

    $self->_fetch_subrequests(
        result  => \@result,
        subreqs => $subreqs,
        inflate => $params{inflate}
    );

    return @result if $wantarray;

    return $result[0];
}

sub _fetch_subrequests {
    my $self   = shift;
    my %params = @_;

    my $dbh = $self->dbh;

    my $subreqs = $params{subreqs};
    my @result  = @{$params{result}};

    return unless $subreqs && @$subreqs;

    foreach my $subreq (@$subreqs) {
        my $name         = $subreq->[0];
        my $args         = $subreq->[1];
        my $subreq_class = $subreq->[2];
        my $chain        = $subreq->[3];

        my $rel = $subreq_class->schema->relationship($name);

        my $map_from = $rel->map_from_cols;
        my $map_to   = $rel->map_to_cols;

        my @pk;

        # create map values for find related (only if map values havent been
        # created earlier in _row_to_object (in case of preceding one to one
        # rel)
        unless ($args->{pk}) {
          OUTER_LOOP: foreach my $object (@result) {
                my $map_from_concat = '';
                my $first           = 1;
                foreach my $map_from_col (@{$map_from}) {
                    $map_from_concat .= '__' unless $first;
                    $first = 0;
                    next OUTER_LOOP
                      unless defined $object->column($map_from_col);
                    $map_from_concat .= $object->column($map_from_col);
                }
                push @pk, $map_from_concat;
            }
        }

        my $ids = $args->{pk} ? [@{$args->{pk}}] : [@pk];
        next unless @$ids;

        my $nested = delete $args->{nested} || [];

        my $related = [
            $subreq_class->new(dbh => $dbh)->find_related(
                $name,
                ids     => $ids,
                with    => $nested,
                inflate => $params{inflate},
                %$args
            )
        ];

        my $set;
        foreach my $o (@$related) {
            my $id;
            foreach my $map_to_col (@$map_to) {
                if ($rel->is_type(qw/has_and_belongs_to_many/)) {
                    $id .= '__' . $o->virtual_column('map__' . $map_to_col);
                }
                else {
                    $id .= '__' . $o->column($map_to_col);
                }
            }
            $set->{$id} ||= [];
            push @{$set->{$id}}, $o;
        }

      OUTER_LOOP: foreach my $o (@result) {
            my $parent = $o;
            foreach my $part (@$chain) {
                if (my $related = $parent->{related}->get($part)) {
                    $parent = $related;
                }
                else {
                    next OUTER_LOOP;
                }
            }

            $parent->{related}->set($name => []);

            next unless $parent->column($map_from->[0]);

            my $id;
            foreach my $map_from_col (@$map_from) {
                $id .= '__' . $parent->column($map_from_col);
            }

            next unless $set->{$id};

            $parent->{related}->push($name, @{$set->{$id}});
        }
    }
}

sub _resolve_where {
    my $self   = shift;
    my %params = @_;

    my $class = $self->schema->class;

    return unless $params{where} && @{$params{where}};

    my $where = [@{$params{where}}];
    my $sql   = $params{sql};

    my $dbh = $self->dbh;

    my $i = 0;
    while ($i < @$where) {
        if (ref $where->[$i] eq 'SCALAR') {
            $sql->where($where->[$i]);
            $i++;
            next;
        }

        my $key   = $where->[$i];
        my $value = $where->[$i + 1];

        if ($key =~ m/\./) {
            my $parent = $class;
            my $source;
            my $one_to_many = 0;
            while ($key =~ s/^(\w+)\.//) {
                my $name = $1;
                my $rel  = $parent->schema->relationship($name);
                $rel->build($dbh);

                if ($rel->is_has_many || $rel->is_has_and_belongs_to_many) {
                    $one_to_many = 1;
                }

                if ($rel->is_has_and_belongs_to_many) {
                    $sql->source($rel->to_map_source);
                }

                $source = $rel->to_source;
                $sql->source($source);

                #$sql->columns($rel->foreign_class->schema->primary_keys);

                $parent = $rel->foreign_class;
            }

            $sql->where($source->{as} . '.' . $key => $value);

            $sql->group_by('id') if $one_to_many;

            # TODO: group by primary key
        }
        else {
            $sql->first_source;
            $sql->where($key => $value);
        }

        $i += 2;
    }
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

sub _update_objects {
    my $self   = shift;
    my %params = @_;

    my $dbh = $self->dbh;

    my %set     = @{$params{set}};
    my @columns = keys %set;
    my @values  = values %set;

    my $sql = ObjectDB::SQL::Update->new;
    $sql->table($self->schema->table);
    $sql->columns(\@columns);
    $sql->values(\@values);
    $sql->where($params{where});

    if ($ENV{OBJECTDB_DEBUG}) {
        warn "$sql";
        warn join(', ', @{$sql->bind});
    }

    my $sth = $dbh->prepare("$sql");
    return unless $sth;

    my $rv = $sth->execute(@{$sql->bind});
    return unless $rv;

    return 0 if $rv eq '0E0';

    return $rv;
}

sub count {
    my $self   = shift;
    my %params = @_;

    my $dbh = $self->dbh;

    $self->schema->build($dbh);

    my $sql = ObjectDB::SQL::Select->new;

    my $table = $self->schema->table;

    $sql->source($table);
    $sql->columns(\q/COUNT(*)/);

    # FIXME
    if (my $where = $params{where}) {
        $self->_resolve_where(where => $where, sql => $sql);
    }

    warn "$sql" if DEBUG;

    my $hash_ref = $dbh->selectrow_hashref("$sql", {}, @{$sql->bind});
    return unless $hash_ref && ref $hash_ref eq 'HASH';

    my @values = values %$hash_ref;
    return shift @values;
}

sub _normalize_with {
    my $self = shift;
    my ($with) = @_;

    return [] unless $with;

    $with = [$with] unless ref $with eq 'ARRAY';

    my %with;
    my $last_key;
    foreach my $name (@$with) {
        if (ref $name eq 'HASH') {
            # FIXME this is normal!
            #die
            #  'pass relationship before passing any further options as hashref'
            #  unless $last_key;
            #$with{$last_key} = {%{$with{$last_key}}, %$name};
            if (!$last_key) {
                $with{delete $name->{name}} = $name;
                $last_key = undef;
            }
            else {
                $with{$last_key} = {%{$with{$last_key}}, %$name};
            }
        }
        else {
            # FIXME wtf
            #die 'use: with => ["foo",{...}], not: with => [qw/ foo {...} /]'
            #  if $name =~ m/^\{/;

            $with{$name} = {};
            $last_key = $name;
        }
    }
    #use Data::Dumper; warn Dumper(\%with);

    my $parts = {};
    foreach my $rel (keys %with) {
        my $name   = '';
        my $parent = $parts;
        while ($rel =~ s/^(\w+)\.?//) {
            $name .= $name ? '.' . $1 : $1;
            $parent->{$1} ||= $with{$name} || {columns => []};
            $parent->{$1}->{nested} ||= {} if $rel;
            $parent = $parent->{$1}->{nested} if $rel;
        }
    }

    my $walker = sub {
        my $code_ref = shift;
        my $parts    = shift;

        # Already normalized
        return $parts if ref($parts) eq 'ARRAY';

        my $rv;
        foreach my $key (sort keys %$parts) {
            push @$rv, ($key => $parts->{$key});

            if (my $subparts = $parts->{$key}->{nested}) {
                $rv->[-1]->{nested} = _execute_code_ref($code_ref, $subparts);
            }
        }

        return $rv;
    };

    return _execute_code_ref($walker, $parts);
}

sub _resolve_with {
    my $self   = shift;
    my %params = @_;

    my $dbh = $self->dbh;

    my $main = $params{main};
    my $with = $params{with};
    my $sql  = $params{sql};

    my $subreqs = [];

    return $subreqs unless $with && @$with;

    my $walker = sub {
        my ($code_ref, $class, $with, $passed_rel_chain, $passed_table_chain,
            $parent_with_args)
          = @_;

        for (my $i = 0; $i < @$with; $i += 2) {
            my $name = $with->[$i];
            my $args = $with->[$i + 1];

            my $rel_chain = $passed_rel_chain ? [@$passed_rel_chain] : [];
            my $table_chain =
              $passed_table_chain ? [@$passed_table_chain] : [];

            my $rel = $class->schema->relationship($name);
            $rel->build($dbh);

            my $parent_args = $parent_with_args || $main;

            if ($rel->is_type(qw/has_many has_and_belongs_to_many/)) {

                ### Parent has always access to mapping data which is saved
                ### in child, mapping data saved in child because each child
                ### only has one parent, but parent can have many children with
                ### varying mapping columns for each relationship
                $parent_args->{child_args} ||= [];
                push @{$parent_args->{child_args}}, $args;


                ### Load columns that are required for object mapping,
                ### not necessarily equal to "map_from", as parent can have
                ### many children (map_from cols of all children have to be loaded)
                push @{$parent_args->{_mapping_columns}}, keys %{$rel->map};


               # Save mapping data in subrequest, preceding main or one-to-one
               # object can access this data via "child_args"
                $args->{map_from} = $rel->map_from_cols;
                $args->{map_to}   = $rel->map_to_cols;

                # Save with-args in subrequest
                # $chain for multi-level object-mapping
                push @$subreqs, [$name, $args, $class, $rel_chain];

            }
            else {
                push @$rel_chain, $name;

                # Force addition of source (duplicates allowed)
                # create alias_prefix in case of duplicates (table chain)
                my $alias_prefix;
                my $source = $rel->to_source;
                if ($sql->has_source($source)) {
                    $alias_prefix = join('__', @$table_chain) . '__';
                }

                push @$table_chain, $rel->foreign_table;

                # Add source before resolving children to get correct order
                # Add where constraint as join args
                $source =
                  $rel->to_source($args->{where}, $alias_prefix,
                    $args->{parent_name});
                $sql->add_source($source);

                if (my $subwith = $args->{nested}) {
                    for (my $i = 0; $i < @$subwith; $i += 2) {
                        $subwith->[$i + 1]->{parent_name} = $source->{as};
                    }

                    _execute_code_ref($code_ref, $rel->foreign_class,
                        $subwith, $rel_chain, $table_chain, $args);
                }

                $args->{columns} = $self->_resolve_columns(
                    {   columns          => $args->{columns},
                        _mapping_columns => $args->{_mapping_columns},
                        schema           => $rel->foreign_class->schema
                    }
                );

                # Switch back to right source
                $sql->source($source);
                $sql->columns([@{$args->{columns}}]);
            }
        }
    };

    _execute_code_ref($walker, $self->schema->class, $with);

    return $subreqs;
}

sub _resolve_columns {
    my $self   = shift;
    my $params = shift;

    my $schema = $params->{schema};

    my $load_selected_columns = $params->{columns};

    my $load_all_columns = 1 unless ($load_selected_columns);

    my $mapping_columns = $params->{_mapping_columns};

    my $columns = [];

    if ($load_selected_columns) {
        $columns =
          ref $load_selected_columns eq 'ARRAY'
          ? [@$load_selected_columns]
          : [$load_selected_columns];
    }
    elsif ($load_all_columns) {
        $columns = [$schema->columns];
        return $columns;
    }

    # Always load primary keys
    $columns = $self->_merge_arrays($columns, [$schema->primary_key]);

    # Load columns required for mapping
    $columns = $self->_merge_arrays($columns, $mapping_columns);

    return $columns;
}

sub _inflate_columns {
    my $self = shift;
    my ($class, $inflate) = @_;

    return unless $inflate;

    die 'inflate has to be array ref' unless ref $inflate eq 'ARRAY';

    for (my $i = 0; $i < @$inflate; $i += 2) {
        my $inflation_class  = $inflate->[$i];
        my $inflation_method = $inflate->[$i + 1];

        $inflation_class = $self->namespace . '::' . $inflation_class
          if $self->namespace;

        if ($class eq $inflation_class) {
            if ($inflation_method =~ /^inflate_/) {
                return $inflation_method;
            }
            else {
                return 'inflate_' . $inflation_method;
            }

            last;
        }
    }

    return;
}

sub _row_to_object {
    my $self   = shift;
    my %params = @_;

    my $dbh = $self->dbh;

    my $row     = $params{row};
    my $sql     = $params{sql};
    my $with    = $params{with};
    my $inflate = $params{inflate};

    my @columns = $sql->columns;

    my $object = $self->schema->class->new(dbh => $dbh);
    foreach my $column (@columns) {
        $object->column($column => shift @$row);
    }

    my $sources = [@{$sql->sources}];
    shift @$sources;

    $with ||= [];

    my $walker = sub {
        my ($code_ref, $object, $with, $inflate) = @_;

        for (my $i = 0; $i < @$with; $i += 2) {
            my $name = $with->[$i];
            my $args = $with->[$i + 1];

            my $rel = $object->schema->relationship($name);

            my $inflation_method =
              $self->_inflate_columns($rel->foreign_class, $inflate);

            next if $rel->is_type(qw/has_many has_and_belongs_to_many/);

            my $rel_object = $rel->foreign_class->new(dbh => $dbh);

            my $source = shift @$sources;

            Carp::croak(q/No more columns left for mapping/) unless @$row;

            foreach my $column (@{$source->{columns}}) {
                # FIXME
                if (ref $column eq 'HASH') {
                    $column = $column->{name};
                }
                $rel_object->column($column => shift @$row);
            }

            $rel_object->{is_modified} = 0;

            if ($rel_object->id) {
                $object->{related}->set($name => $rel_object);
            }
            # FIXME
            #else {
            #    $object->{related}->set($name => 0);
            #}

            # Prepare column inflation
            if ($rel_object->id) {
                $rel_object->$inflation_method if $inflation_method;
            }

            foreach my $child_args (@{$args->{child_args}}) {
                if ($child_args->{map_from} && $rel_object->id) {
                    my $map_from_concat = '';
                    my $first           = 1;
                    foreach my $map_from_col (@{$child_args->{map_from}}) {
                        $map_from_concat .= '__' unless $first;
                        $first = 0;
                        $map_from_concat
                          .= $rel_object->column($map_from_col);
                    }
                    push @{$child_args->{pk}}, $map_from_concat;
                }
            }

            if (my $subwith = $args->{nested}) {
                _execute_code_ref($code_ref, $rel_object, $subwith);
            }
        }
    };

    _execute_code_ref($walker, $object, $with, $inflate);

    Carp::croak(
        q/Not all columns of current row could be mapped to the object/)
      if @$row;

    $object->{is_in_db}    = 1;
    $object->{is_modified} = 0;

    return $object;
}

sub _execute_code_ref {
    my $code_ref = shift;
    $code_ref->($code_ref, @_);
}

sub _merge_arrays {
    my $self = shift;
    my ($array1, $array2) = @_;

    my @columns1;
    foreach my $value (@$array1) {
        push @columns1, ref $value eq 'HASH' ? $value : {name => $value};
    }

    my @columns2;
    foreach my $value (@$array2) {
        push @columns2, ref $value eq 'HASH' ? $value : {name => $value};
    }

    foreach my $column (@columns2) {
        if (!grep {$column->{name} eq $_->{name}} @columns1) {
            push @columns1, $column;
        }
    }

    return [@columns1];
}

1;
