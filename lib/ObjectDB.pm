package ObjectDB;

use strict;
use warnings;

use base 'ObjectDB::Base';

__PACKAGE__->attr([qw/is_modified is_in_db/] => 0);
__PACKAGE__->attr('conn');

use constant DEBUG => $ENV{OBJECTDB_DEBUG} || 0;

our $VERSION = '0.990201';

require Carp;
use ObjectDB::Iterator;
use ObjectDB::Schema;
use ObjectDB::SQL::Delete;
use ObjectDB::SQL::Insert;
use ObjectDB::SQL::Select;
use ObjectDB::SQL::Update;

use Data::Dumper;

sub new {
    my $self   = shift->SUPER::new;

    $self->init(@_) if @_;

    return $self;
}

sub init {
    my $self   = shift;
    my %params = @_;

    if (my $conn = delete $params{conn}) {
        $self->conn($conn);
    }
    else {
        $self->conn($self->init_conn);
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
              .ref($self)->schema->table
              .qq/ or unknown relationship in class: /.ref($self);
        }
    }

    $self->column(%$columns);
}

sub schema {
    my $class = shift;
    my $table = shift;

    $table ||= '';

    my $class_name = ref $class ? ref $class : $class;

    return $ObjectDB::Schema::objects{$class_name}
      ||= ObjectDB::Schema->new(table => $table, class => $class_name, @_);
}

sub init_conn {}

sub id {
    my $self = shift;

    return $self->column($self->schema->primary_keys->[0]);
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

    foreach my $column (@{$self->schema->columns}) {
        push @columns, $column if exists $self->{columns}->{$column};
    }

    return @columns;
}

sub count {
    my $class  = shift;
    my %params = @_;

    my $conn = delete $params{conn} || $class->init_conn;
    Carp::croak qq/Connector is required/ unless $conn;

    $class->schema->build($conn);

    my $sql = ObjectDB::SQL::Select->new;

    my $table = $class->schema->table;
    #my @pk    = map {"`$table`.`$_`"} @{$class->schema->primary_keys};
    #my $pk    = join(' || ', @pk);

    $sql->source($table);
    $sql->columns(\qq/COUNT(*)/);

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

    Carp::croak qq/Connector required/ unless $self->conn;

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

            $self->is_in_db(1);

            if (my $auto_increment = $class->schema->auto_increment) {
                my $id =
                  $dbh->last_insert_id(undef, undef, $class->schema->table,
                    $auto_increment);
                $self->column($auto_increment => $id);
            }

            $self->is_modified(0);

            while (my ($key, $value) = each %{$self->{related}}) {
                $self->{related}->{$key} =
                  $self->create_related($key => $value);
            }

            return $self;
        }
    );
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
        Carp::croak qq/Relationship is not multiple/;
    }

    my $wantarray = wantarray;
    my $conn = $self->conn;
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
                    my $object = $rel->foreign_class->find_or_create(conn => $conn, %$d);

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
    push @where, @{$rel->where} if $rel->where;
    push @where, @{delete $params{where}} if $params{where};

    Carp::croak qq/Action on this relationship type is not supported/
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
            conn  => $self->conn,
            where => [$to => $self->column($from), @where],
            %params
        );
    }
    else {
        my ($from, $to) = %{$rel->map};

        delete $self->{related}->{$name};

        return $rel->foreign_class->delete(
            conn  => $self->conn,
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
    return $related if $related;
    return undef if defined $related && $related == 0;

    my $type = $rel->type;
    if ($type eq 'has_one' || $type eq 'belongs_to') {

        #use Data::Dumper;
        #warn Dumper $self->find_related($name, first => 1);
        return $self->find_related($name, first => 1);
    }
    else {
        return $self->find_related($name);
    }
}

sub find {
    my $class  = shift;
    my %params = @_;

    my $conn = delete $params{conn} || $class->init_conn;
    Carp::croak qq/Connector is required/ unless $conn;

    $class->schema->build($conn);

    my $single = $params{first} || $params{single} ? 1 : 0;

    my $sql = ObjectDB::SQL::Select->new;
    $sql->source($class->schema->table);

    my @columns;
    if ($params{columns}) {
        @columns = @{$params{columns}};
    }
    else {
        @columns = @{$class->schema->columns};
    }

    # Primary keys are always loaded
    foreach my $pk ( @{$class->schema->primary_keys} ){
        my $add_pk_column = 1;
        foreach my $passed_column ( @columns ){
            $add_pk_column = 0 if $pk eq $passed_column;
        }
        unshift @columns, $pk if $add_pk_column;
    }

    $sql->columns([@columns]);

    if (my $id = delete $params{id}) {
        $sql->where($class->schema->primary_keys->[0] => $id);
        $single = 1;
    }
    else {
        if (my $where = $params{where}) {
            $class->_resolve_where(where => $where, sql => $sql);
        }
    }

    $sql->limit($params{limit}) if $params{limit};
    $sql->limit(1) if $single;

    $sql->order_by($params{order_by}) if $params{order_by};

    my $subreqs = [];
    my $with;
    my $main = {};
    if ($with = $params{with}) {
        $with = $class->_normalize_with($with);
        $class->_resolve_with( main=>$main, with => $with, sql => $sql, subreqs => $subreqs);
    }

    return $conn->txn(
        sub {
            my ($dbh) = @_;

            warn "$sql" if DEBUG;
            my $sth = $dbh->prepare("$sql");
            return unless $sth;

            my $rv = $sth->execute(@{$sql->bind});
            return unless $rv;

            if (wantarray) {
                my $rows = $sth->fetchall_arrayref;
                return () unless $rows && @$rows;

                my @pk;
                my @result;
                foreach my $row (@$rows) {
                    my $object = $class->_row_to_object(
                        conn  => $conn,
                        row  => $row,
                        sql  => $sql,
                        with => $with
                      );
                    push @result, $object;
        
                    if ( $main->{map_from} ){
                        my $map_from_concat = '';
                        foreach my $map_from_col ( @{$main->{map_from}} ) {
                            $map_from_concat .= $object->column( $map_from_col );
                        }
                        push @pk, $map_from_concat;
                    }

                }

                #warn Dumper \@pk;

                if ($subreqs && @$subreqs) {
                    foreach my $subreq (@$subreqs) {
                        my $name         = $subreq->[0];
                        my $args         = $subreq->[1];
                        my $subreq_class = $subreq->[2];
                        my $chain        = $subreq->[3];
                        my $parent_args  = $subreq->[4];

                        my $map_from = $parent_args->{map_from}
                          || $main->{map_from}
                          || die('no map_from cols');

                        my $map_to = $parent_args->{map_to}
                          || $main->{map_to}
                          || die('no map_to cols');

                        my $ids = $parent_args->{pk} ? [@{$parent_args->{pk}}] : [@pk];
                        my $nested = delete $args->{nested} || [];

                        my $related = [
                            $subreq_class->find_related(
                                $name,
                                conn  => $conn,
                                ids   => $ids,
                                with  => $nested,
                                map_to   => $map_to,
                                %$args
                            )
                        ];

                        # DO NOT SORT, WRITE FAILING TEST FOR CASE THAT ORDER CHANGES
                        #@$map_to = sort @$map_to;
                        #@$map_from = sort @$map_from;

                        my $set;
                        foreach my $o (@$related) {
                            my $id;
                            foreach my $map_to_col ( @$map_to ){
                                $id .= $o->column($map_to_col);
                            }
                            $set->{$id} ||= [];
                            push @{$set->{$id}}, $o;
                        }

                        #warn Dumper $set;
                        #$related = {map { $_->id => $_ } @$related};

                        OUTER_LOOP: foreach my $o (@result) {
                            my $parent = $o;
                            foreach my $part ( @$chain ){
                                if ( $parent->{related}->{$part} ){
                                    $parent = $parent->{related}->{$part};
                                }
                                else {
                                    next OUTER_LOOP;
                                }
                            }

                            next unless $parent->column($map_from->[0]);

                            $parent->{related}->{$name} = [];

                            my $id;
                            foreach my $map_from_col ( @$map_from ){
                                $id .= $parent->column($map_from_col);
                            }

                            $set->{$id} ||= [];
                            push @{$parent->{related}->{$name}}, @{$set->{$id}};
                        }
                    }
                }

                return @result;
            }
            elsif ($single) {
                my $rows = $sth->fetchall_arrayref;
                return unless $rows && @$rows;

                my $object = $class->_row_to_object(
                    conn  => $conn,
                    row  => $rows->[0],
                    sql  => $sql,
                    with => $with
                );

                return $object unless $subreqs && @$subreqs;

                SUB_REQ: foreach my $subreq (@$subreqs) {
                    my $name         = $subreq->[0];
                    my $args         = $subreq->[1];
                    my $subreq_class = $subreq->[2];
                    my $chain        = $subreq->[3];
                    my $parent_args  = $subreq->[4];

                    my $ids = $parent_args->{pk} ? [@{$parent_args->{pk}}] : [$object->id];

                    my $parent = $object;
                    foreach my $part ( @$chain ){
                        if ( $parent->{related}->{$part} ){
                            $parent = $parent->{related}->{$part};
                        }
                        else {
                            next SUB_REQ;
                        }
                    }

                    next SUB_REQ unless $parent->id;

                    $parent->{related}->{$name} =
                        [$subreq_class->find_related($name => conn => $object->conn,
                            ids => $ids, with => delete $args->{nested}, %$args)];
                }

                return $object;
            }
            else {
                return ObjectDB::Iterator->new(
                    cb => sub {
                        my @row = $sth->fetchrow_array;
                        return unless @row;

                        return $class->_row_to_object(
                            conn  => $conn,
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

sub find_or_create {
    my $class = shift;
    my %params = @_;

    my $conn = delete $params{conn} || $class->init_conn;

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

            @where = ("articles.$from" => $self->id);
        }
        else {
            my ($from, $to) = %{$rel->map};

            Carp::croak qq/$from is required for find_related/ unless $self->column($from);

            @where = ($to => $self->column($from));

            $params{first} = 1 if $rel->type =~ m/belongs_to/;
        }
    }
    else {
        $conn = $params{conn} || $class->init_conn;
        Carp::croak qq/Connector is required/ unless $conn;

        if ($rel->is_has_and_belongs_to_many) {
            die 'todo';
        }
        else {

            if ( $params{map_to} ){

            my @map_to = @{$params{map_to}};

            if ( @map_to> 1 ){
                @map_to = map {$_ = '`'.$_.'`'} @map_to;
                ### SQLite
                ### TO DO: mysql: concat
                ### TO DO: find better way to pass join(' || ', @map_to) --> unless $key =~/^`/; in where.pm
                @where = ( join(' || ', @map_to) => [@{delete $params{ids}}]);
                
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
    my $self   = shift;
    my %params = @_;

    my $conn = delete $params{conn} || $self->conn || $self->init_conn;

    if (ref($self)) {
        return $self unless $self->is_modified;

        $self->conn($conn);

        Carp::croak qq/Connector is required/ unless $conn;

        Carp::croak "->update: no primary or unique keys specified"
          unless $self->_are_primary_keys_set;

        my @columns =
          grep { !$self->schema->is_primary_key($_) } $self->columns;
        my @values = map { $self->column($_) } @columns;

        my $sql = ObjectDB::SQL::Update->new;
        $sql->table($self->schema->table);
        $sql->columns(\@columns);
        $sql->values(\@values);
        $sql->where(map { $_ => $self->column($_) }
              @{$self->schema->primary_keys});

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
    else {
        my $class = $self;

        my $set = $params{set};
        my (@columns, @values);
        for (my $i = 0; $i < @$set; $i += 2) {
            push @columns, $set->[$i];
            push @values, $set->[$i + 1];
        }

        my $sql = ObjectDB::SQL::Update->new;
        $sql->table($class->schema->table);
        $sql->columns(\@columns);
        $sql->values(\@values);
        $sql->where($params{where});

        if (DEBUG) {
            warn "$sql" if DEBUG;
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
}

sub delete {
    my $self   = shift;
    my %params = @_;

    my $conn =
         delete $params{conn}
      || (ref($self) && $self->conn)
      || $self->init_conn;

    if (ref($self) && !%params) {
        $self->conn($conn) unless $self->conn;

        Carp::croak "->delete: no primary or unique keys specified"
          unless $self->_are_primary_keys_set;

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
                          %{$rel->map_class->schema->relationship($map_from)->map};

                        $related = $rel->map_class->find(
                            conn  => $conn,
                            where => [$to => $self->column($from)]
                        );
                    }
                    else {
                        $related = $self->find_related($name);
                    }

                    while (my $r = $related->next) {
                        $r->delete(conn => $conn);
                    }
                }

                my @columns = $self->columns;
                my @keys =
                  grep { $self->schema->is_primary_key($_) } @columns;
                @keys = grep { $self->schema->is_unique_key($_) } @columns
                  unless @keys;

                my $sql = ObjectDB::SQL::Delete->new;
                $sql->table($self->schema->table);
                $sql->where([map { $_ => $self->column($_) } @keys]);

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

sub to_hash {
    my $self = shift;

    my @columns = $self->columns;

    my $hash = {};
    foreach my $key (@columns) {
        $hash->{$key} = $self->column($key);
    }

    #foreach my $name (keys %{$self->_related}) {
    #my $rel = $self->_related->{$name};

    #die "unknown '$name' relationship" unless $rel;

    #if (ref $rel eq 'ARRAY') {
    #$hash->{$name} = [];
    #foreach my $r (@$rel) {
    #push @{$hash->{$name}}, $r->to_hash;
    #}
    #}
    #else {
    #$hash->{$name} = $rel->to_hash;
    #}
    #}

    return $hash;
}

sub _resolve_where {
    my $class  = shift;
    my %params = @_;

    my $where = $params{where};
    my $sql   = $params{sql};

    return unless $where && @$where;

    for (my $i = 0; $i < @$where; $i += 2) {
        my $key   = $where->[$i];
        my $value = $where->[$i + 1];

        if ($key =~ m/\./) {
            my $parent = $class;
            my $source;
            while ($key =~ s/(\w+)\.//) {
                my $name = $1;
                my $rel  = $parent->schema->relationship($name);

                if ($rel->is_has_and_belongs_to_many) {
                    $sql->source($rel->to_map_source);
                }

                $source = $rel->to_source;
                $sql->source($source);

                #$sql->columns($rel->foreign_class->schema->primary_keys);

                $parent = $rel->foreign_class;
            }

            $sql->where($source->{as} . '.' . $key => $value);
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

    my $main   = $params{main};
    my $with   = $params{with};
    my $sql    = $params{sql};
    my $subreqs = $params{subreqs};

    return unless $with;

    my $walker;
    $walker = sub {
        my ($class, $with, $passed_chain, $parent_args) = @_;

        for (my $i = 0; $i < @$with; $i += 2) {
            my $name = $with->[$i];
            my $args = $with->[$i + 1];

            my $chain = $passed_chain ? [@$passed_chain] : [];

            my $rel = $class->schema->relationship($name);

            if ($rel->is_type(qw/has_many has_and_belongs_to_many/)) {
                if (delete $args->{auto} && !$args->{columns}) {
                    # Make sure that no columns are loaded
                    $args->{columns} = [];
                }

                # Load columns that are required for object mapping
                if ($args->{columns}){
                    while (my ($from, $to) = each %{$rel->map}) {
                        unless ( grep { $_ eq $to } @{$args->{columns}} ){
                            push @{$args->{columns}}, $to;                 
                        }
                    }
                }

                # Save map-from-columns and map-to-columns in with or main
                if ( $parent_args ) {
                    while (my ($from, $to) = each %{$rel->map}) {
                        push @{$parent_args->{map_from}}, $from;                 
                        push @{$parent_args->{map_to}}, $to;
                    }
                }
                else {
                    while (my ($from, $to) = each %{$rel->map}) {
                        push @{$main->{map_from}}, $from;                 
                        push @{$main->{map_to}}, $to;     
                    }
                }

                # $chain for multi-level object-mapping
                # $parent_args to map subreq data to correct parent ids
                push @$subreqs, [$name, $args, $class, $chain, $parent_args];

            }
            else {
                push @$chain, $name;

                $sql->source($rel->to_source);

                if ($args->{auto}) {
                    $sql->columns($rel->foreign_class->schema->primary_keys);
                }
                elsif (!$args->{columns}) {
                    $sql->columns($rel->foreign_class->schema->columns);
                }
                else {
                    #$sql->columns($rel->foreign_class->schema->primary_keys);
                    $sql->columns($args->{columns});
                }

                if (my $subwith = $args->{nested}) {
                    $walker->($rel->foreign_class, $subwith, $chain, $args);
                }
            }
        }
    };
    $walker->($class, $with);
}

sub _normalize_with {
    my $class = shift;
    my $with  = shift;

    $with = [$with] unless ref $with eq 'ARRAY';

    my %with;
    my $last_key;
    foreach my $name (@$with) {
        if (ref($name) eq 'HASH') {
            $with{$last_key} = {%{$with{$last_key}}, %$name};
        }
        else {
            $with{$name} = {};
            $last_key = $name;
        }
    }

    my $parts = {};
    foreach my $rel (keys %with) {
        my $name = '';
        my $parent = $parts;
        while ($rel =~ s/^(\w+)\.?//) {
            $name .= $name ? '.' . $1 : $1;
            $parent->{$1} ||= $with{$name} || {auto => 1};
            $parent->{$1}->{nested} ||= {} if $rel;
            $parent = $parent->{$1}->{nested} if $rel;
        }
    }


    my $walker; $walker = sub {
        my $parts = shift;

        # Already normalized
        return $parts if ref($parts) eq 'ARRAY';

        my $rv;
        foreach my $key (sort keys %$parts) {
            push @$rv, ($key => $parts->{$key});

            if (my $subparts = $parts->{$key}->{nested}) {
                $rv->[-1]->{nested} = $walker->($subparts);
            }
        }

        return $rv;
    };

    return $walker->($parts);
}

sub primary_keys_values {
    my $self = shift;

    my $pk;
    foreach my $name (@{$self->schema->primary_keys}) {
        push @$pk, $self->column($name);
    }

    return $pk;
}

sub _are_primary_keys_set {
    my $self = shift;

    my @ok = grep {
             $self->schema->is_primary_key($_)
          or $self->schema->is_unique_key($_)
    } $self->columns;

    return @ok ? 1 : 0;
}

sub _row_to_object {
    my $class  = shift;
    my %params = @_;

    my $conn  = $params{conn};
    my $row  = $params{row};
    my $sql  = $params{sql};
    my $with = $params{with};

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

    my $walker; $walker = sub {
        my ($self, $with) = @_;

        for (my $i = 0; $i < @$with; $i += 2) {
            my $name = $with->[$i];
            my $args = $with->[$i + 1];

            my $rel = $self->schema->relationship($name);

            next if ($rel->is_type(qw/has_many has_and_belongs_to_many/));

            my $object = $rel->foreign_class->new;
            $object->conn($conn);

            my $source = shift @$sources;

            Carp::croak qq/No more columns left for mapping/ unless @$row;

            foreach my $column (@{$source->{columns}}) {
                $object->column($column => shift @$row);
            }

            $object->is_modified(0);
            if ( $object->id ){
                $self->{related}->{$name} = $object;
            }
            else {
                $self->{related}->{$name} = 0;
            }

            $args->{pk} ||= [];

            if ( $args->{map_from} && $object->id ){
                my $map_from_concat = '';
                foreach my $map_from_col ( @{$args->{map_from}} ) {
                    $map_from_concat .= $object->column( $map_from_col );
                }
                push @{$args->{pk}}, $map_from_concat;
            }

            if (my $subwith = $args->{nested}) {
                $walker->($object, $subwith);
            }
        }
    };

    $walker->($self, $with);

    #use Data::Dumper;
    #warn Dumper $row;
    Carp::croak qq/Not all the rows are mapped to the object/ if @$row;

    $self->is_in_db(1);
    $self->is_modified(0);

    return $self;
}

1;
