package ObjectDB;

use strict;
use warnings;

use base 'ObjectDB::Base';

use constant DEBUG => $ENV{OBJECTDB_DEBUG} || 0;

our $VERSION = '0.990201';

require Carp;
use ObjectDB::Columns;
use ObjectDB::Related;
use ObjectDB::Schema;
use ObjectDB::Iterator;
use ObjectDB::SQL::Insert;
use ObjectDB::SQL::Select;
use ObjectDB::SQL::Delete;
use ObjectDB::SQL::Update;
use ObjectDB::Utils 'single_to_plural';
use Scalar::Util qw(blessed);

sub BUILD {
    my $self = shift;

    $self->schema->build($self->dbh);

    my $columns = delete $self->{columns};

    $self->{columns} ||= ObjectDB::Columns->new(schema => $self->schema);
    $self->{related} ||= ObjectDB::Related->new;

    if ($columns) {
        $self->set_columns(%$columns);
    }

    return $self;
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

    my $table = @_ == 1 ? shift @_ : '';

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

    #return if defined $related && $related == 0;

    # Allow tests to make sure that checked data was prefetched
    die "OBJECTDB_FORCE_PREFETCH: data has to be prefetched: '$name'"
      if $ENV{OBJECTDB_FORCE_PREFETCH};

    if ($rel->is_type(qw/has_one belongs_to/)) {
        warn "find_related $name";
        $self->{related}
          ->set($name => $self->find_related($name, first => 1));
        return $self->{related}->get($name);
    }

    my @objects = $self->find_related($name);
    $self->{related}->push($name, @objects);
    return wantarray ? @objects : \@objects;
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

sub find_related {
    my $self     = shift;
    my $rel_name = shift;
    my %params   = @_;

    # Passed values
    my $passed_where = delete $params{where};
    my $passed_with  = delete $params{with};

    my $dbh = $self->dbh;

    # Get relationship object
    my $rel = $self->schema->relationship($rel_name);
    $rel->build($dbh);

    # Initialize
    my @where;
    my @with;
    my $find_class;
    my $ids;

    $ids = delete $params{ids};

    # Get ids
    unless ($ids) {

        # Get values for mapping columns (ids)
        my $first = 1;
        my $map_from_concat;
        foreach my $from (@{$rel->map_from_cols}) {
            $map_from_concat .= '__' unless $first;
            $first = 0;
            return unless defined $self->{columns}->get($from);
            $map_from_concat .= $self->{columns}->get($from);
        }
        $ids = [$map_from_concat];
    }

    # Make sure that row object is returned in scalar context (not iterator
    # object) in case of belongs_to rel
    if ($rel->is_belongs_to || $rel->is_belongs_to_one) {
        $params{single} = 1;
    }

    # Passed where, passed with and find class
    if ($rel->is_has_and_belongs_to_many) {
        push @with,
          ( $rel->map_to,
            {   nested  => $passed_with,
                where   => $passed_where,
                columns => delete $params{columns}
            }
          );
        $find_class = $rel->map_class;
    }
    else {
        @with  = @$passed_with  if $passed_with;
        @where = @$passed_where if $passed_where;
        $find_class = $rel->foreign_class;
    }

    # Prepare where to search only for related objects
    my @map_to = @{$rel->map_to_cols};
    if (@map_to > 1) {
        my $concat = '-concat(' . join(',', @map_to) . ')';
        push @where, ($concat => [@$ids]);
    }
    else {
        push @where, ($map_to[0] => [@$ids]);
    }
    push @where, @{$rel->where} if $rel->where;

    # Return results
    if ($rel->is_has_and_belongs_to_many) {
        my @results = $find_class->new(dbh => $dbh)->find(
            where => [@where],
            with  => [@with],
            %params
        );

        my @final;
        foreach my $result (@results) {
            my $final = $result->related($rel->map_to);
            next unless $final;
            $final->virtual_column(
                'map__' . $map_to[0] => $result->column($map_to[0]));
            push @final, $final;
        }
        return @final;
    }
    else {
        if (wantarray && !$params{first}) {
            my @rel_object = $find_class->new(dbh => $dbh)->find(
                where => [@where],
                with  => [@with],
                %params
            );

            $self->{related}->push($rel_name => @rel_object);

            return @rel_object;
        }
        else {
            my $rel_object = $find_class->new(dbh => $dbh)->find(
                where => [@where],
                with  => [@with],
                %params
            );

            # FIXME
            #$self->{related}->set($rel_name => $rel_object);

            return $rel_object;
        }
    }
}

sub _resolve_id {
    my $self = shift;
    my $id   = shift;
    my $sql  = shift;

    if (ref $id ne 'ARRAY' && ref $id ne 'HASH') {
        my @primary_key = $self->schema->primary_key;
        die
          'FIND: id param has to be array or hash ref if there is more than one primary key column (e.g. id=>{ pk1 => 1, pk2 => 2 })'
          unless (@primary_key == 1);
    }

    my %where;
    if (ref $id eq 'ARRAY') {
        %where = @$id;
    }
    elsif (ref $id eq 'HASH') {
        %where = %$id;
    }
    else {
        my @pk_cols = $self->schema->primary_key;
        %where = ($pk_cols[0] => $id);
    }

    unless ($self->schema->is_primary_key(keys %where)
        || $self->schema->is_unique_key(keys %where))
    {
        die 'FIND: passed columns do not form primary or unique key';
    }

    $sql->where(%where);
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

    return $self->_update_instance(@_) unless $self->{columns}->is_empty;

    return $self->_update_objects(@_);
}

sub _update_instance {
    my $self   = shift;
    my %params = @_;

    return $self unless $self->{columns}->is_modified;

    my $dbh = $self->dbh;

    my @primary_or_unique_key = $self->{columns}->pk_or_uk_columns;

    Carp::croak q/->update: no primary or unique keys specified/
      unless @primary_or_unique_key;

    my @columns = $self->{columns}->regular_columns;
    my @values = map { $self->{columns}->get($_) } @columns;

    my $sql = ObjectDB::SQL::Update->new;;
    $sql->table($self->schema->table);
    $sql->columns(\@columns);
    $sql->values(\@values);
    $sql->where(map { $_ => $self->{columns}->get($_) }
          @primary_or_unique_key);

    warn "$sql" if DEBUG;

    my $sth = $dbh->prepare("$sql");
    return unless $sth;

    my $rv = $sth->execute(@{$sql->bind});
    return unless $rv && $rv eq '1';

    $self->{columns}->not_modified;

    $self->{is_in_db} = 1;

    return $self;
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

        if (defined $rel && $rel == 0) {
            $hash->{$name} = {};
            next;
        }

        Carp::croak qq/Unknown '$name' relationship/ unless $rel;

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

sub delete {
    my $self   = shift;
    my %params = @_;

    # FIXME cascade

    return $self->_delete_instance unless %params || $params{cascade};

    # TODO txn
    my $dbh = $self->dbh;

    my $count = 0;
    my $found = $self->find(%params);
    while (my $r = $found->next) {
        $r->delete;
        $count++;
    }

    return $count;
}

sub delete_related {
    my $self   = shift;
    my $name   = shift;
    my %params = @_;

    my $rel = $self->schema->relationship($name);
    $rel->build($self->dbh);

    my @where;
    push @where, @{$rel->where}           if $rel->where;
    push @where, @{delete $params{where}} if $params{where};

    Carp::croak q/Action on this relationship type is not supported/
      unless $rel->is_type(qw/has_one has_many has_and_belongs_to_many/);

    if ($rel->is_has_and_belongs_to_many) {
        my ($to, $from) =
          %{$rel->map_class->schema->relationship($rel->map_from)->map};

        for (my $i = 0; $i < @where; $i += 2) {
            my $name = $rel->name;
            if ($where[$i] =~ s/^$name\.//) {
                $where[$i] = $rel->map_to . '.' . $where[$i];
            }
        }

        return $rel->map_class->new(dbh => $self->dbh)->delete(
            where => [$to => $self->{columns}->get($from), @where],
            %params
        );
    }
    else {
        my ($from, $to) = %{$rel->map};

        $self->{related}->delete($name);

        return $rel->foreign_class->new(dbh => $self->dbh)->delete(
            where => [$to => $self->{columns}->get($from), @where],
            %params
        );
    }
}

sub _delete_instance {
    my $self = shift;
    my (%params) = @_;

    my @primary_or_unique_key = $self->{columns}->pk_or_uk_columns;

    Carp::croak q/->delete: no primary or unique keys specified/
      unless @primary_or_unique_key;

    my $dbh = $self->dbh;

    # FIXME
    if ($params{cascade}) {
        # TODO txn
        my @child_rel = $self->schema->child_relationships;
        foreach my $name (@child_rel) {
            my $rel = $self->schema->relationship($name);
            $rel->build($dbh);

            my $related;

            if ($rel->is_has_and_belongs_to_many) {
                my $map_from = $rel->map_from;

                my ($to, $from) =
                  %{$rel->map_class->schema->relationship($map_from)->map};

                $related =
                  $rel->map_class->new(dbh => $dbh)
                  ->find(where => [$to => $self->{columns}->get($from)]);
            }
            else {
                $related = $self->find_related($name);
            }

            next unless $related;

            while (my $r = $related->next) {
                $r->delete;
            }
        }
    }

    my $sql = ObjectDB::SQL::Delete->new;
    $sql->table($self->schema->table);
    $sql->where(
        [map { $_ => $self->{columns}->get($_) } @primary_or_unique_key]);

    warn "$sql" if DEBUG;

    my $sth = $dbh->prepare("$sql");
    return unless $sth;

    my $rv = $sth->execute(@{$sql->bind});
    return unless $rv && $rv eq '1';

    $self->{is_in_db} = 0;

    return $self;
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

sub create {
    my $self = shift;

    my $sql = ObjectDB::SQL::Insert->new;

    $sql->table($self->schema->table);
    $sql->columns([$self->{columns}->names]);
    my $driver = $self->dbh->{'Driver'}->{'Name'};
    $sql->driver($driver);

    my $dbh = $self->dbh;

    # TODO txn
    my @values = $self->{columns}->values;

    if (DEBUG) {
        warn "$sql";
        warn join(', ', @values);
    }

    my $sth = $dbh->prepare("$sql");
    return unless $sth;

    my $rv = $sth->execute(@values);
    return unless $rv && $rv eq '1';

    $self->_set_auto_increment_column($dbh);

    $self->{columns}->not_modified;

    foreach my $name ($self->{related}->names) {
        my $value = $self->{related}->get($name);
        next if blessed($value);

        my $rel_object = $self->create_related($name => $value);

        $self->{related}->set($name => $rel_object);
    }

    $self->{is_in_db} = 1;

    return $self;
}

sub create_related {
    my $self = shift;
    my ($name, $data) = @_;

    my $rel = $self->schema->relationship($name);
    $rel->build($self->dbh);

    if (ref $data eq 'ARRAY'
        && (!$rel->is_has_many && !$rel->is_has_and_belongs_to_many))
    {
        Carp::croak(q/Relationship is not multiple/);
    }

    my @params = ();
    while (my ($from, $to) = each %{$rel->map}) {
        push @params, ($to => $self->{columns}->get($from));
    }

    push @params, @{$rel->where} if $rel->where;

    my $wantarray = wantarray;

    my $dbh = $self->dbh;

    # TODO txn
    if ($rel->is_has_many) {
        my $result;
        $data = [$data] unless ref $data eq 'ARRAY';
        foreach my $d (@$data) {
            push @$result,
              $rel->foreign_class->new(dbh => $dbh)->set_columns(%$d, @params)
              ->create;
        }

        return $wantarray ? @$result : $result;
    }
    elsif ($rel->is_has_and_belongs_to_many) {
        $data = [$data] unless ref $data eq 'ARRAY';

        my $map_from = $rel->map_from;
        my $map_to   = $rel->map_to;

        my ($from_foreign_pk, $from_pk) =
          %{$rel->map_class->schema->relationship($map_from)->map};

        my ($to_foreign_pk, $to_pk) =
          %{$rel->map_class->schema->relationship($map_to)->map};

        foreach my $d (@$data) {
            my $object =
              $rel->foreign_class->new(dbh => $dbh)->find_or_create(%$d);
            my $rel = $rel->map_class->new(dbh => $dbh)->set_columns(
                $from_foreign_pk => $self->{columns}->get($from_pk),
                $to_foreign_pk   => $object->column($to_pk)
            )->create;
        }

        # TODO
    }
    else {
        my $rel_object =
          $rel->foreign_class->new(dbh => $dbh)->set_columns(%$data, @params)
          ->create;

        $self->{related}->set($name => $rel_object);

        return $rel_object;
    }
}

sub _set_auto_increment_column {
    my $self = shift;
    my ($dbh) = @_;

    if (my $auto_increment = $self->schema->auto_increment) {
        my $id =
          $dbh->last_insert_id(undef, undef, $self->schema->table,
            $auto_increment);
        $self->{columns}->set($auto_increment => $id);
    }
}

1;
