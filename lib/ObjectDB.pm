package ObjectDB;

use strict;
use warnings;

use base 'ObjectDB::Base';

__PACKAGE__->attr([qw/is_modified is_in_db/] => 0);

use constant DEBUG => $ENV{OBJECTDB_DEBUG} || 0;

our $VERSION = '0.990201';

require Carp;
use ObjectDB::Iterator;
use ObjectDB::Rows;
use ObjectDB::Schema;
use ObjectDB::SQL::Delete;
use ObjectDB::SQL::Insert;
use ObjectDB::SQL::Select;
use ObjectDB::SQL::Update;
use ObjectDB::Utils 'single_to_plural';

use Data::Dumper;

sub new {
    my $self = shift->SUPER::new;

    $self->init(@_) if @_;

    return $self;
}

sub plural_class_name {
    my $class = shift;
    $class = ref $class ? ref $class : $class;

    return single_to_plural($class);
}

sub init {
    my $self   = shift;
    my %params = @_;

    if (my $conn = delete $params{conn}) {
        $self->conn($conn);
    }

    $self->schema->build($self->conn);

    my $columns = {};
    while (my ($key, $value) = each %params) {
        if ($self->schema->is_column($key)) {
            $columns->{$key} = $value;
        }
        elsif ($self->schema->is_relationship($key)) {
            $self->{related}->{$key} = $value;
        }
        else {
            Carp::croak qq/Unknown column '$key' in table: /
              . ref($self)->schema->table
              . qq/ or unknown relationship in class: /
              . ref($self);
        }
    }

    $self->column(%$columns);
}

sub conn {
    my $self = shift;

    return $self->{conn} = $_[0] if @_;

    if (ref($self)) {
        return $self->{conn} if $self->{conn};

        return $self->{conn} = $self->init_conn;
    }

    return $self->init_conn;
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

sub rows_as_object {

    # Overwrite this method to turn rows_as_object on
    # sub rows_as_object {1;}
    return undef;
}

sub init_conn { }

sub id {
    my $self = shift;

    my @values = map { $self->column($_) } $self->schema->primary_key;

    return wantarray ? @values : $values[0];
}

sub column {
    my $self = shift;

    $self->{columns} ||= {};

    if (@_ == 1) {
        return defined $_[0] ? $self->{columns}->{$_[0]} : undef;
    }
    elsif (@_ >= 2) {
        my %columns = @_;
        while (my ($key, $value) = each %columns) {
            if (defined $self->{columns}->{$key} && defined $value) {
                $self->is_modified(1) if $self->{columns}->{$key} ne $value;
            }
            elsif (defined $self->{columns}->{$key} || defined $value) {
                $self->is_modified(1);
            }

            $self->{columns}->{$key} = $value;
        }
    }

    return $self;
}

sub columns {
    my $self = shift;

    my @columns;

    foreach my $column ($self->schema->columns) {
        push @columns, $column if exists $self->{columns}->{$column};
    }

    return @columns;
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

sub count {
    my $class  = shift;
    my %params = @_;

    my $conn = delete $params{conn} || $class->conn;
    Carp::croak q/Connector is required/ unless $conn;

    $class->schema->build($conn);

    my $sql = ObjectDB::SQL::Select->new;

    my $table = $class->schema->table;

    $sql->source($table);
    $sql->columns(\q/COUNT(*)/);

    $sql->where(%params);

    warn "$sql" if DEBUG;

    return $conn->run(
        sub {
            my $dbh = shift;

            my $hash_ref = $dbh->selectrow_hashref("$sql", {}, @{$sql->bind});
            return unless $hash_ref && ref $hash_ref eq 'HASH';

            my @values = values %$hash_ref;
            return shift @values;
        }
    );
}

sub create {
    my $class  = shift;
    my %params = @_;

    my $self = ref($class) ? $class : $class->new(%params);

    Carp::croak q/Connector required/ unless $self->conn;

    my $sql = ObjectDB::SQL::Insert->new;
    $sql->table($class->schema->table);
    $sql->columns([$self->columns]);
    $sql->driver($self->conn->driver);

    return $self->conn->txn(
        sub {
            my $dbh = shift;

            my @values = map { $self->column($_) } $self->columns;

            if (DEBUG) {
                warn "$sql";
                warn join(', ', @values);
            }

            my $sth = $dbh->prepare("$sql");
            return unless $sth;

            my $rv = $sth->execute(@values);
            return unless $rv && $rv eq '1';

            $self->_set_auto_increment_column($dbh);

            $self->is_in_db(1);
            $self->is_modified(0);

            while (my ($key, $value) = each %{$self->{related}}) {
                $self->{related}->{$key} =
                  $self->create_related($key => $value);
            }

            return $self;
        }
    );
}

sub _set_auto_increment_column {
    my $self = shift;
    my $dbh  = shift;

    if (my $auto_increment = $self->schema->auto_increment) {
        my $id =
          $dbh->last_insert_id(undef, undef, $self->schema->table,
            $auto_increment);
        $self->column($auto_increment => $id);
    }
}

sub create_related {
    my $self = shift;
    my $name = shift;
    my $data = shift;

    my $rel = $self->schema->relationship($name);

    my @params = ();
    while (my ($from, $to) = each %{$rel->map}) {
        push @params, ($to => $self->column($from));
    }

    push @params, @{$rel->where} if $rel->where;

    if (ref $data eq 'ARRAY'
        && (!$rel->is_has_many && !$rel->is_has_and_belongs_to_many))
    {
        Carp::croak q/Relationship is not multiple/;
    }

    my $wantarray = wantarray;
    my $conn      = $self->conn;
    return $conn->txn(
        sub {
            if ($rel->is_has_many) {
                my $result;
                $data = [$data] unless ref $data eq 'ARRAY';
                foreach my $d (@$data) {
                    push @$result, $rel->foreign_class->create(
                        conn => $conn,
                        %$d, @params
                    );
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
                      $rel->foreign_class->find_or_create(conn => $conn, %$d);

                    my $rel = $rel->map_class->create(
                        conn             => $conn,
                        $from_foreign_pk => $self->column($from_pk),
                        $to_foreign_pk   => $object->column($to_pk)
                    );
                }
            }
            else {
                return $self->{related}->{$name} =
                  $rel->foreign_class->create(conn => $conn, %$data, @params);
            }
        }
    );
}

sub delete_related {
    my $self   = shift;
    my $name   = shift;
    my %params = @_;

    my $rel = $self->schema->relationship($name);

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

        return $rel->map_class->delete(
            conn => $self->conn,
            where => [$to => $self->column($from), @where],
            %params
        );
    }
    else {
        my ($from, $to) = %{$rel->map};

        delete $self->{related}->{$name};

        return $rel->foreign_class->delete(
            conn => $self->conn,
            where => [$to => $self->column($from), @where],
            %params
        );
    }
}

sub related {
    my $self = shift;
    my $name = shift;

    my $rel = $self->schema->relationship($name);

    my $related = $self->{related}->{$name};

    # Rows as objects (optional - when method rows_as_object
    # returns true, lazy - objects created only when method related
    # or aliases are called)
    if ($self->rows_as_object && $related && ref $related eq 'ARRAY') {
        my $rows = ObjectDB::Rows->new;
        $rows->rows($related);
        $related = $rows;
        $self->{related}->{$name} = $related;
    }

    return $related if $related;
    return undef if defined $related && $related == 0;

    # Allow tests to make sure that checked data was prefetched
    die "OBJECTDB_FORCE_PREFETCH: data has to be prefetched: '$name'"
      if $ENV{OBJECTDB_FORCE_PREFETCH};

    if ($rel->is_type(qw/has_one belongs_to/)) {
        return $self->find_related($name, first => 1);
    }
    my @objects = $self->find_related($name);
    return wantarray ? @objects : \@objects;
}


# get the max/min top n results per group (e.g. the top 4 comments for each article)
# WARNING: the proposed SQL works fine with multiple thausend rows, but might consume
# a lot of resources in cases that amount of data is much bigger (not tested so far)
sub _resolve_max_min_n_per_group {
    my $class  = shift;
    my $params = shift;

    # Get params
    my $sql    = $params->{sql};
    my $type   = uc($params->{type});
    my $group  = $params->{group};
    my $column = $params->{column};
    my $top    = $params->{top} || 1;
    my $strict = $params->{strict};

    $group  = ref $group      ? [@$group] : [$group];
    $strict = defined $strict ? $strict   : 1;

    my $op;
    if ($type eq 'MIN') {
        $op = '>';
    }
    if ($type eq 'MAX') {
        $op = '<';
    }

    my $table            = $class->schema->table;
    my $join_table_alias = $class->schema->table . '_' . $type;

    my @constraint1;
    foreach my $column (@$group) {

        # generate a more complex query in case that grouping
        # depends on other tables
        if ($column =~ /[.]/) {
            $class->_resolve_max_min_n_per_group_multi_table($params);
        }

        push @constraint1,
          ("$table.$column" => \"`$join_table_alias`.`$column`");
    }

    # Add main source
    $sql->source($class->schema->table);

    # join bigger/smaller entries
    my @constraint2;
    push @constraint2,
      ("$table.$column" => {$op, \"`$join_table_alias`.`$column`"});

    # or join entries with lower ids in case of same values
    my @constraint3;
    push @constraint3,
      ( "$table.$column" => \"`$join_table_alias`.`$column`",
        "$table.id"      => {'>', \"`$join_table_alias`.`id`"}
      );

    my $constraint;
    if (!$strict) {
        $constraint = [@constraint1, @constraint2];
    }
    else {
        $constraint =
          [@constraint1, -or => [@constraint2, -and => \@constraint3]];
    }

    $sql->source(
        {   name       => $class->schema->table,
            as         => $join_table_alias,
            join       => 'left',
            constraint => $constraint
        }
    );

    $sql->group_by('id');

    if ($top == 1) {
        $sql->where($join_table_alias . '.id' => undef);
    }
    else {
        $sql->having(\qq/COUNT(*) < $top/);
    }

}

### EXPERIMENTAL
### a more complex query is required in case that grouping
### is performed based on data in other tables
sub _resolve_max_min_n_per_group_multi_table {
    my $class  = shift;
    my $params = shift;

    # Get params
    my $sql    = $params->{sql};
    my $type   = uc($params->{type});
    my $group  = $params->{group};
    my $column = $params->{column};
    my $top    = $params->{top} || 1;
    my $strict = $params->{strict};
    my $conn   = $params->{conn};

    my $op;
    my $order;
    if ($type eq 'MIN') {
        $op    = '>';
        $order = 'asc';
    }
    if ($type eq 'MAX') {
        $op    = '<';
        $order = 'desc';
    }

    $group  = ref $group      ? [@$group] : [$group];
    $strict = defined $strict ? $strict   : 1;


    # Build first subrequest
    my $sub_sql_1 = ObjectDB::SQL::Select->new;
    $sub_sql_1->source($class->schema->table);
    $sub_sql_1->columns($class->schema->columns);
    $class->_resolve_multi_table(
        where     => $group,
        sql       => $sub_sql_1,
        col_alias => 'OBJECTDB_COMPARE_1'
    );


    # Build second subrequest
    my $sub_sql_2 = ObjectDB::SQL::Select->new;
    $sub_sql_2->source($class->schema->table);
    $sub_sql_2->columns($class->schema->columns);

    $class->_resolve_multi_table(
        where     => $group,
        sql       => $sub_sql_2,
        col_alias => 'OBJECTDB_COMPARE_2'
    );


    # Build main request
    $sql->source(
        {   name    => $class->schema->table,
            as      => $class->schema->table,
            sub_req => $sub_sql_1->to_string
        }
    );
    $sql->columns($class->schema->columns);


    my $table            = $class->schema->table;
    my $join_table_alias = $class->schema->table . '_' . $type;

    # join bigger/smaller entries
    my @constraint2;
    push @constraint2,
      ("$table.$column" => {$op, \qq/`$join_table_alias`.`$column`/});

    # or join entries with lower ids in case of same values
    my @constraint3;
    push @constraint3,
      ( "$table.$column" => \"`$join_table_alias`.`$column`",
        "$table.id"      => {'>', \"`$join_table_alias`.`id`"}
      );

    my $constraint;
    if (!$strict) {
        $constraint =
          ['OBJECTDB_COMPARE_1' => \q/OBJECTDB_COMPARE_2/, @constraint2];
    }
    else {
        $constraint = [
            'OBJECTDB_COMPARE_1' => \q/OBJECTDB_COMPARE_2/,
            -or                  => [@constraint2, -and => \@constraint3]
        ];
    }

    $sql->source(
        {   name       => $join_table_alias,
            as         => $join_table_alias,
            sub_req    => $sub_sql_2->to_string,
            join       => 'left',
            constraint => $constraint
        }
    );


    $sql->group_by('id');
    $sql->order_by("OBJECTDB_COMPARE_1 asc, $column $order, id asc");

    if ($top == 1) {
        $sql->where($join_table_alias . '.id' => undef);
    }
    else {
        $sql->having(\qq/COUNT(*) < $top/);
    }

    #warn "$sql";

}

sub _resolve_multi_table {
    my $class  = shift;
    my %params = @_;

    my $where     = $params{where};
    my $sql       = $params{sql};
    my $col_alias = $params{col_alias};

    return unless $where && @$where;

    for (my $i = 0; $i < @$where; $i += 2) {
        my $key   = $where->[$i];
        my $value = $where->[$i + 1];

        if ($key =~ m/\./) {
            my $parent = $class;
            my $source;
            my $one_to_many = 0;
            while ($key =~ s/(\w+)\.//) {
                my $name = $1;
                my $rel  = $parent->schema->relationship($name);

                if ($rel->is_has_many) {
                    $one_to_many = 1;
                }

                $source = $rel->to_source();
                $sql->source($source);

                $parent = $rel->foreign_class;
            }
            die 'only one to one allowed' if $one_to_many;
            $sql->columns({name => $key, as => $col_alias});
        }

    }
}

sub find {
    my $class  = shift;
    my %params = @_;

    if (ref $class && $class->columns){
        die q/find method can only be performed on table object, not on row object/;
    }

    my $conn = delete $params{conn} || $class->conn;
    Carp::croak q/Connector is required/ unless $conn;

    $class->schema->build($conn);

    my $single = $params{first} || $params{single} ? 1 : 0;

    my $sql = ObjectDB::SQL::Select->new(driver => $conn->driver);

    my $main = {};

    if (my $maxmin = $params{max} || $params{min}) {
        $class->_resolve_max_min_n_per_group(
            {   sql  => $sql,
                type => $params{max} ? 'max' : 'min',
                %$maxmin
            }
        );
    }
    # Standard case
    else {
        $sql->source($class->schema->table);
    }

    # Resolve "with" here to add columns needed to map related objects
    my $subreqs = [];
    my $with;
    if ($with = $params{with}) {
        $with = $class->_normalize_with($with);
        $class->_resolve_with(
            main    => $main,
            with    => $with,
            sql     => $sql,
            subreqs => $subreqs
        );
    }

    # Resolve columns
    $main->{columns} = $class->_resolve_columns(
        {   columns => $params{columns},
            _mapping_columns =>
              [@{$main->{_mapping_columns} || []}, @{$params{map_to} || []}]
        }
    );


    $sql->source($class->schema->table);    ### switch back to main source
    $sql->columns([@{$main->{columns}}]);

    if (my $id = delete $params{id}) {
        $class->_resolve_id($id, $sql);
        $single = 1;
    }
    elsif (my $where = $params{where}) {
        $class->_resolve_where(where => $where, sql => $sql);
    }

    $sql->limit($params{limit}) if $params{limit};
    $sql->limit(1) if $single;

    $sql->order_by($params{order_by}) if $params{order_by};

    return $conn->txn(
        sub {
            my ($dbh) = @_;

            warn "$sql" if $ENV{OBJECTDB_DEBUG};
            my $sth = $dbh->prepare("$sql");
            return unless $sth;

            my $rv = $sth->execute(@{$sql->bind});
            die 'execute failed' unless $rv;

            my $wantarray = wantarray;

            if ($wantarray || $params{rows_as_object} || $single) {
                my $rows = $sth->fetchall_arrayref;
                return unless $rows && @$rows;

                my @result;

                # Prepare column inflation
                my $inflation_method =
                  $class->_inflate_columns($params{inflate});

              OUTER_LOOP: foreach my $row (@$rows) {
                    my $object = $class->_row_to_object(
                        conn    => $conn,
                        row     => $row,
                        sql     => $sql,
                        with    => $with,
                        inflate => $params{inflate}
                    );

                    # Column inflation
                    $object->$inflation_method if $inflation_method;

                    push @result, $object;
                }

                if ($subreqs && @$subreqs) {
                    $class->_fetch_subrequests(
                        result  => \@result,
                        conn    => $conn,
                        subreqs => $subreqs,
                        inflate => $params{inflate}
                    );
                }


                if ($wantarray) {
                    return @result;
                }
                elsif ($params{rows_as_object}) {
                    my $rows_object = ObjectDB::Rows->new;
                    return $rows_object->rows(\@result);
                }
                elsif ($single) {
                    $result[0];
                }
            }
            else {
                return ObjectDB::Iterator->new(
                    cb => sub {
                        my @row = $sth->fetchrow_array;
                        return unless @row;

                        return $class->_row_to_object(
                            conn => $conn,
                            row  => [@row],
                            sql  => $sql,
                            with => $with
                        );
                    }
                );
            }
        }
    );
}

sub _resolve_id {
    my $class = shift;
    my $id    = shift;
    my $sql   = shift;


    if (ref $id ne 'ARRAY' && ref $id ne 'HASH') {
        my @primary_key = $class->schema->primary_key;
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
        my @pk_cols = $class->schema->primary_key;
        %where = ($pk_cols[0] => $id);
    }

    unless ($class->schema->is_primary_key(keys %where)
        || $class->schema->is_unique_key(keys %where))
    {
        die 'FIND: passed columns do not form primary or unique key';
    }

    $sql->where(%where);

}

sub _add_new_values_to_array {
    my $self   = shift;
    my $params = shift;

    my $old_values = $params->{old_values};
    my $new_values = $params->{new_values};

    # Only add new values (if they do not already exist in array)
    foreach my $new_value (@$new_values) {
        unless (grep { $_ eq $new_value } @$old_values) {
            unshift @{$old_values}, $new_value;
        }
    }
    return $self;
}


sub _fetch_subrequests {
    my $class  = shift;
    my %params = @_;

    my $conn    = $params{conn};
    my $subreqs = $params{subreqs};
    my @result  = @{$params{result}};

    foreach my $subreq (@$subreqs) {
        my $name         = $subreq->[0];
        my $args         = $subreq->[1];
        my $subreq_class = $subreq->[2];
        my $chain        = $subreq->[3];

        my $map_from = $args->{map_from}
          || die('no map_from cols');

        my $map_to = $args->{map_to}
          || die('no map_to cols');


        my @pk;

     # create map values for find related (only if map values havent been
     # created earlier in _row_to_object (in case of preceding one to one rel)
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
            $subreq_class->find_related(
                $name,
                conn    => $conn,
                ids     => $ids,
                with    => $nested,
                map_to  => $map_to,
                inflate => $params{inflate},
                %$args
            )
        ];

        my $set;
        foreach my $o (@$related) {
            my $id;
            foreach my $map_to_col (@$map_to) {
                $id .= $o->column($map_to_col);
            }
            $set->{$id} ||= [];
            push @{$set->{$id}}, $o;
        }

        #warn Dumper $set;
        #$related = {map { $_->id => $_ } @$related};

      OUTER_LOOP: foreach my $o (@result) {
            my $parent = $o;
            foreach my $part (@$chain) {
                if ($parent->{related}->{$part}) {
                    $parent = $parent->{related}->{$part};
                }
                else {
                    next OUTER_LOOP;
                }
            }

            next unless $parent->column($map_from->[0]);

            $parent->{related}->{$name} = [];

            my $id;
            foreach my $map_from_col (@$map_from) {
                $id .= $parent->column($map_from_col);
            }

            $set->{$id} ||= [];
            push @{$parent->{related}->{$name}}, @{$set->{$id}};
        }
    }
}

sub find_or_create {
    my $class  = shift;
    my %params = @_;

    my $conn = delete $params{conn} || $class->conn;

    my $self = $class->find(conn => $conn, where => [%params], single => 1);
    return $self if $self;

    return $class->create(conn => $conn, %params);
}

sub find_related {
    my $class  = shift;
    my $name   = shift;
    my %params = @_;

    my $rel = $class->schema->relationship($name);

    my $conn;

    my @where;

    if (ref($class)) {
        my $self = $class;

        $conn = $self->conn;

        if ($rel->is_has_and_belongs_to_many) {
            my ($to, $from) =
              %{$rel->map_class->schema->relationship($rel->map_from)->map};
        }
        else {
            my ($from, $to) = %{$rel->map};

            return unless $self->column($from);

            @where = ($to => $self->column($from));

            $params{first} = 1 if $rel->type =~ m/belongs_to/;
        }
    }
    else {
        $conn = $params{conn} || $class->conn;
        Carp::croak q/Connector is required/ unless $conn;

        if ($rel->is_has_and_belongs_to_many) {
            die 'todo';
        }
        else {
            if ($params{map_to}) {
                my @map_to = @{$params{map_to}};

                if (@map_to > 1) {
                    my $concat = '-concat(' . join(',', @map_to) . ')';

                    @where = ($concat => [@{delete $params{ids}}]);

                }
                else {
                    @where = ($map_to[0] => [@{delete $params{ids}}]);
                }
            }
        }
    }

    push @where, @{$rel->where}           if $rel->where;
    push @where, @{delete $params{where}} if $params{where};

    return $rel->foreign_class->find(
        conn  => $conn,
        where => [@where],
        %params
    );
}

sub update_column {
    my $self = shift;

    $self->column(@_);

    return $self->update;
}

sub update {
    my $self = shift;

    # Row object
    return $self->_update_instance(@_) if ref $self && $self->columns;

    # Class or table object
    return $self->_update_objects(@_);
}

sub _update_instance {
    my $self   = shift;
    my %params = @_;

    return $self unless $self->is_modified;

    my $conn = $params{conn} || $self->conn;

    Carp::croak q/Connector is required/ unless $conn;

    $self->conn($conn);

    my @primary_or_unique_key = $self->_primary_or_unique_key_columns;

    Carp::croak q/->update: no primary or unique keys specified/
      unless @primary_or_unique_key;

    my @columns = $self->_regular_columns;
    my @values = map { $self->column($_) } @columns;

    my $sql = ObjectDB::SQL::Update->new;
    $sql->table($self->schema->table);
    $sql->columns(\@columns);
    $sql->values(\@values);
    $sql->where(map { $_ => $self->column($_) } @primary_or_unique_key);

    warn "$sql" if DEBUG;

    $self->conn->run(
        sub {
            my $dbh = shift;

            my $sth = $dbh->prepare("$sql");
            return unless $sth;

            my $rv = $sth->execute(@{$sql->bind});
            return unless $rv && $rv eq '1';

            $self->is_in_db(1);
            $self->is_modified(0);
        }
    );

    return $self;
}

sub _update_objects {
    my $class  = shift;
    my %params = @_;

    my $conn = $params{conn} || $class->conn;

    my %set     = @{$params{set}};
    my @columns = keys %set;
    my @values  = values %set;

    my $sql = ObjectDB::SQL::Update->new;
    $sql->table($class->schema->table);
    $sql->columns(\@columns);
    $sql->values(\@values);
    $sql->where($params{where});

    if ($ENV{OBJECTDB_DEBUG}) {
        warn "$sql";
        warn join(', ', @{$sql->bind});
    }

    $conn->run(
        sub {
            my $dbh = shift;

            my $sth = $dbh->prepare("$sql");
            return unless $sth;

            my $rv = $sth->execute(@{$sql->bind});
            return unless $rv;
        }
    );

    return 1;
}

sub delete {
    my $self   = shift;
    my %params = @_;

    my $conn = delete $params{conn} || $self->conn;

    if (ref($self) && !%params) {
        $self->conn($conn) if $conn;

        return $self->_delete_instance;
    }
    else {
        return $conn->txn(
            sub {
                my $dbh = shift;

                my $found = $self->find(conn => $conn, %params);
                while (my $r = $found->next) {
                    $r->delete(conn => $conn);
                }

                return 1;
            }
        );
    }
}

sub _delete_instance {
    my $self = shift;

    my @primary_or_unique_key = $self->_primary_or_unique_key_columns;

    Carp::croak q/->delete: no primary or unique keys specified/
      unless @primary_or_unique_key;

    my $conn = $self->conn;

    return $conn->txn(
        sub {
            my $dbh = shift;

            my @child_rel = $self->schema->child_relationships;
            foreach my $name (@child_rel) {
                my $rel = $self->schema->relationship($name);

                my $related;

                if ($rel->is_has_and_belongs_to_many) {
                    my $map_from = $rel->map_from;

                    my ($to, $from) =
                      %{$rel->map_class->schema->relationship($map_from)
                          ->map};

                    $related = $rel->map_class->find(
                        conn => $conn,
                        where => [$to => $self->column($from)]
                    );
                }
                else {
                    $related = $self->find_related($name);
                }

                next unless $related;

                while (my $r = $related->next) {
                    $r->delete(conn => $conn);
                }
            }

            my $sql = ObjectDB::SQL::Delete->new;
            $sql->table($self->schema->table);
            $sql->where(
                [map { $_ => $self->column($_) } @primary_or_unique_key]);

            warn "$sql" if DEBUG;

            my $sth = $dbh->prepare("$sql");
            return unless $sth;

            my $rv = $sth->execute(@{$sql->bind});
            return unless $rv && $rv eq '1';

            $self->is_in_db(0);

            return $self;
        }
    );
}

sub _primary_key_columns {
    my $self = shift;

    my @primary_key = $self->schema->primary_key;
    foreach my $column (@primary_key) {
        return () unless defined $self->{columns}->{$column};
    }

    return @primary_key;
}

sub _regular_columns {
    my $self = shift;

    my @columns;

    foreach my $column ($self->schema->regular_columns) {
        push @columns, $column if exists $self->{columns}->{$column};
    }

    return @columns;
}

sub _unique_key_columns {
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

sub _primary_or_unique_key_columns {
    my $self = shift;

    my @columns = $self->_primary_key_columns;

    return @columns if @columns;

    push @columns, $self->_unique_key_columns;

    return @columns;
}

sub to_hash {
    my $self = shift;

    my @columns = $self->columns;

    my $hash = {};
    foreach my $key (@columns) {
        $hash->{$key} = $self->column($key);
    }

    foreach my $key ($self->virtual_columns) {
        $hash->{$key} = $self->virtual_column($key);
    }

    foreach my $name (keys %{$self->{related}}) {
        my $rel = $self->{related}->{$name};

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

sub _resolve_where {
    my $class  = shift;
    my %params = @_;

    $class = ref $class ? ref $class : $class;

    return unless $params{where} && @{$params{where}};

    my $where = [@{$params{where}}];
    my $sql   = $params{sql};

    for (my $i = 0; $i < @$where; $i += 2) {
        my $key   = $where->[$i];
        my $value = $where->[$i + 1];

        if ($key =~ m/\./) {
            my $parent = $class;
            my $source;
            my $one_to_many = 0;
            while ($key =~ s/(\w+)\.//) {
                my $name = $1;
                my $rel  = $parent->schema->relationship($name);

                if ($rel->is_has_many) {
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

            # TO DO: group by primary key

        }
        else {
            $sql->first_source;
            $sql->where($key => $value);
        }
    }

    #use Data::Dumper;
    #warn Dumper $sql;
    #warn "$sql";
}

sub _resolve_with {
    my $class  = shift;
    my %params = @_;

    $class = ref $class ? ref $class : $class;

    my $main    = $params{main};
    my $with    = $params{with};
    my $sql     = $params{sql};
    my $subreqs = $params{subreqs};

    return unless $with;

    my $walker = sub {
        my ($code_ref, $class, $with, $passed_chain, $parent_with_args) = @_;

        for (my $i = 0; $i < @$with; $i += 2) {
            my $name = $with->[$i];
            my $args = $with->[$i + 1];

            my $chain = $passed_chain ? [@$passed_chain] : [];

            my $rel = $class->schema->relationship($name);

            my $parent_args = $parent_with_args || $main;

            if ($rel->is_type(qw/has_many has_and_belongs_to_many/)) {

                ### Parent has always access to mapping data which is saved
                ### in child, mapping data saved in child because each child
                ### only has one parent, but parent can have many childs with
                ### varying mapping columns for each relationship
                $parent_args->{child_args} ||= [];
                push @{$parent_args->{child_args}}, $args;


                ### Load columns that are required for object mapping,
                ### not necessarily equal to "map_from", as parent can have
                ### many childs (map_from cols of all childs have to be loaded)
                push @{$parent_args->{_mapping_columns}}, keys %{$rel->map};


               # Save mapping data in subrequest, preceding main or one-to-one
               # object can access this data via "child_args"
                while (my ($from, $to) = each %{$rel->map}) {
                    push @{$args->{map_from}}, $from;
                    push @{$args->{map_to}},   $to;
                }

                # Save with-args in subrequest
                # $chain for multi-level object-mapping
                push @$subreqs, [$name, $args, $class, $chain];

            }
            else {
                push @$chain, $name;

                # Add source now to get correct order
                # Add where constraint as join args
                $sql->source($rel->to_source($args->{where}));

                if (my $subwith = $args->{nested}) {
                    _execute_code_ref($code_ref, $rel->foreign_class,
                        $subwith, $chain, $args);
                }

                $args->{columns} = $rel->foreign_class->_resolve_columns(
                    {   columns          => $args->{columns},
                        _mapping_columns => $args->{_mapping_columns}
                    }
                );

                # Switch back to right source
                $sql->source($rel->to_source);
                $sql->columns([@{$args->{columns}}]);

            }
        }
    };

    _execute_code_ref($walker, $class, $with);

    #use Data::Dumper;
    #warn Dumper $subreqs if $ENV{OBJECTDB_DEBUG};
    #warn Dumper $with if $ENV{OBJECTDB_DEBUG};
    #warn Dumper $main if $ENV{OBJECTDB_DEBUG};

}

sub _resolve_columns {
    my $self   = shift;
    my $params = shift;

    my $class = ref $self ? ref $self : $self;

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
        $columns = [$class->schema->columns];
        return $columns;
    }

    # Always load primary keys
    $class->_add_new_values_to_array(
        {   old_values => $columns,
            new_values => [$class->schema->primary_key]
        }
    );

    # Load columns required for mapping
    $class->_add_new_values_to_array(
        {   old_values => $columns,
            new_values => $mapping_columns
        }
    );

    return $columns;

}


sub _normalize_with {
    my $class = shift;
    my $with  = shift;

    $with = ref $with eq 'ARRAY' ? [@$with] : [$with];

    my %with;
    my $last_key;
    foreach my $name (@$with) {
        if (ref $name eq 'HASH') {
            die
              'pass relationship before passing any further options as hashref'
              unless $last_key;
            $with{$last_key} = {%{$with{$last_key}}, %$name};
        }
        else {
            die 'use: with => ["foo",{...}], not: with => [qw/ foo {...} /]'
              if $name =~ m/^\{/;
            $with{$name} = {};
            $last_key = $name;
        }
    }

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

sub primary_key_values {
    my $self = shift;

    my @values;
    foreach my $name ($self->schema->primary_key) {
        push @values, $self->column($name);
    }

    return @values;
}

sub _row_to_object {
    my $class  = shift;
    my %params = @_;

    $class = ref $class ? ref $class : $class;

    my $conn    = $params{conn};
    my $row     = $params{row};
    my $sql     = $params{sql};
    my $with    = $params{with};
    my $inflate = $params{inflate};

    my @columns = $sql->columns;

    my $self = $class->new;
    $self->conn($conn);
    foreach my $column (@columns) {
        $self->column($column => shift @$row);
    }

    #warn '_row v';
    #warn Dumper $sql;
    #warn Dumper \@columns;
    #warn '_row ^';

    my $sources = [@{$sql->sources}];
    shift @$sources;

    #use Data::Dumper;
    #warn Dumper $with;

    $with ||= [];

    my $walker = sub {
        my ($code_ref, $self, $with, $inflate) = @_;

        for (my $i = 0; $i < @$with; $i += 2) {
            my $name = $with->[$i];
            my $args = $with->[$i + 1];

            my $rel = $self->schema->relationship($name);

            my $inflation_method =
              $rel->foreign_class->_inflate_columns($inflate);

            next if $rel->is_type(qw/has_many has_and_belongs_to_many/);

            my $object = $rel->foreign_class->new;
            $object->conn($conn);

            my $source = shift @$sources;

            Carp::croak q/No more columns left for mapping/ unless @$row;

            foreach my $column (@{$source->{columns}}) {
                $object->column($column => shift @$row);
            }

            $object->is_modified(0);
            if ($object->id) {
                $self->{related}->{$name} = $object;
            }
            else {
                $self->{related}->{$name} = 0;
            }

            # Prepare column inflation
            if ($object->id) {
                $object->$inflation_method if $inflation_method;
            }

            foreach my $child_args (@{$args->{child_args}}) {
                if ($child_args->{map_from} && $object->id) {
                    my $map_from_concat = '';
                    my $first           = 1;
                    foreach my $map_from_col (@{$child_args->{map_from}}) {
                        $map_from_concat .= '__' unless $first;
                        $first = 0;
                        $map_from_concat .= $object->column($map_from_col);
                    }
                    push @{$child_args->{pk}}, $map_from_concat;
                }
            }

            if (my $subwith = $args->{nested}) {
                _execute_code_ref($code_ref, $object, $subwith);
            }
        }
    };

    _execute_code_ref($walker, $self, $with, $inflate);

    #use Data::Dumper;
    #warn Dumper $row;
    Carp::croak
      q/Not all columns of current row could be mapped to the object/
      if @$row;

    $self->is_in_db(1);
    $self->is_modified(0);

    return $self;
}

sub _execute_code_ref {
    my $code_ref = shift;
    $code_ref->($code_ref, @_);
}


sub _inflate_columns {
    my $self    = shift;
    my $inflate = shift;

    return unless $inflate;

    my $class = ref $self ? ref $self : $self;

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


1;
