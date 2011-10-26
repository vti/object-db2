package ObjectDB;

use strict;
use warnings;

use base 'ObjectDB::Base';

use constant DEBUG => $ENV{OBJECTDB_DEBUG} || 0;

our $VERSION = '2.00';

require Carp;
use Scalar::Util qw(blessed);

use ObjectDB::Table;
use ObjectDB::Columns;
use ObjectDB::Related;
use ObjectDB::Schema;
use ObjectDB::SQL::Insert;
use ObjectDB::SQL::Select;
use ObjectDB::SQL::Delete;
use ObjectDB::SQL::Update;
use ObjectDB::Utils 'single_to_plural';

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

sub table {
    my $self = shift;
    my $class = ref $self ? ref $self : $self;

    return ObjectDB::Table->new(class => $class, dbh => $self->dbh);
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

sub load {
    my $self = shift;
    my (%params) = @_;

    my $id = delete $params{id};
    die 'You must specify id' unless defined $id;

    my $sql = ObjectDB::SQL::Select->new(driver => $self->dbh->{'Driver'}->{'Name'});

    $sql->source($self->schema->table);

    my @columns =
      $params{columns} ? @{$params{columns}} : $self->schema->columns;
    $sql->columns(@columns);

    $self->_resolve_id($id, $sql);

    warn "$sql" if $ENV{OBJECTDB_DEBUG};

    my $sth = $self->dbh->prepare("$sql");
    return unless $sth;

    my $rv = $sth->execute(@{$sql->bind});
    die 'execute failed' unless $rv;

    my $rows = $sth->fetchall_arrayref;
    return unless $rows && @$rows;

    my $object = $self->_row_to_object(row => $rows->[0], sql => $sql);

    %$self = %$object;

    return $self;
}

sub find {
    my $self = shift;

    return $self->table->find(@_);
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
        my @results = $find_class->new(dbh => $dbh)->table->find(
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
            my @rel_object = $find_class->new(dbh => $dbh)->table->find(
                where => [@where],
                with  => [@with],
                %params
            );

            $self->{related}->push($rel_name => @rel_object);

            return @rel_object;
        }
        else {
            my $rel_object = $find_class->new(dbh => $dbh)->table->find(
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
    my ($id, $sql) = @_;

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

sub update {
    my $self = shift;
    my (%params) = @_;

    return $self unless $self->{columns}->is_modified;

    # FIXME cascade?

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

sub delete {
    my $self   = shift;
    my %params = @_;

    my @primary_or_unique_key = $self->{columns}->pk_or_uk_columns;

    Carp::croak(q/->delete: no primary or unique keys specified/)
      unless @primary_or_unique_key;

    my $dbh = $self->dbh;

    # FIXME cascade
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
                  ->table->find(where => [$to => $self->{columns}->get($from)]);
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

    my %where = map { $_ => $self->{columns}->get($_) } @primary_or_unique_key;

    my $sql = ObjectDB::SQL::Delete->new;
    $sql->table($self->schema->table);
    $sql->where(%where);

    warn "$sql" if DEBUG;

    my $sth = $dbh->prepare("$sql");
    return unless $sth;

    my $rv = $sth->execute(@{$sql->bind});
    return unless $rv && $rv eq '1';

    $self->{is_in_db} = 0;

    return $self;
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
