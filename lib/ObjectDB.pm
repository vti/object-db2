package ObjectDB;

use strict;
use warnings;

use base 'ObjectDB::Base';

__PACKAGE__->attr([qw/is_modified is_in_db/] => 0);

use constant DEBUG => $ENV{OBJECTDB_DEBUG} || 0;

our $VERSION = '0.990201';

require Carp;
use ObjectDB::Iterator;
use ObjectDB::Schema;
use ObjectDB::SQL::Delete;
use ObjectDB::SQL::Insert;
use ObjectDB::SQL::Select;
use ObjectDB::SQL::Update;
use Scalar::Util qw/weaken isweak/;

sub schema {
    my $class = shift;
    my $table = shift;

    $table ||= '';

    my $class_name = ref $class ? ref $class : $class;

    return $ObjectDB::Schema::objects{$class_name}
      ||= ObjectDB::Schema->new(table => $table, class => $class_name, @_);
}

sub dbh {}

sub _dbh {
    my $self = shift;

    if (@_) {
        $self->{dbh} = $_[0];
        return $self;
    }

    return $self->{dbh};
}

sub txn {
    my $self = shift;
    my $cb   = pop;
    my %params = @_;

    my $dbh = $params{dbh} || (ref($self) && $self->_dbh) || $self->dbh;
    Carp::croak qq/dbh is required/ unless $dbh;

    # Already in transaction
    return $cb->() unless $dbh->{AutoCommit};

    my $raise_error_bak = $dbh->{RaiseError};

    $dbh->{AutoCommit} = 0;
    $dbh->{RaiseError} = 1;

    my $wantarray = wantarray;

    warn 'BEGIN TRANSACTION' if DEBUG;
    my ($rv, @rv);
    if ($wantarray) {
        eval { @rv = $cb->() };
    }
    else {
        eval { $rv = $cb->() };
    }

    if ($@) {
        warn 'ROLLBACK' if DEBUG;
        $dbh->rollback;
        die $DBI::errstr if $raise_error_bak;
        return;
    }

    warn 'COMMIT' if DEBUG;
    $dbh->commit;

    $dbh->{AutoCommit} = 1;
    $dbh->{RaiseError} = $raise_error_bak;

    return $wantarray ? @rv : $rv;
}

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
    my $class = shift;
    my %params = @_;

    my $dbh = delete $params{dbh} || $class->dbh;
    Carp::croak qq/dbh is required/ unless $dbh;

    my $sql = ObjectDB::SQL::Select->new;

    my $table = $class->schema->table;
    my @pk    = map {"`$table`.`$_`"} @{$class->schema->primary_keys};
    my $pk    = join(',', @pk);

    $sql->source($table);
    $sql->columns(\"COUNT(DISTINCT $pk)");

    $sql->where(%params);

    warn "$sql" if DEBUG;

    my $hash_ref = $dbh->selectrow_hashref("$sql", {}, @{$sql->bind});
    return unless $hash_ref && ref $hash_ref eq 'HASH';

    my @values = values %$hash_ref;
    return shift @values;
}

sub create {
    my $class = shift;
    my %params = @_;

    my $dbh = delete $params{dbh} || $class->dbh;
    Carp::croak qq/dbh is required/ unless $dbh;

    $class->schema->build($dbh);

    my $columns = {};
    my $related = {};
    while (my ($key, $value) = each %params) {
        if ($class->schema->is_column($key)) {
            $columns->{$key} = $value;
        }
        elsif ($class->schema->is_relationship($key)) {
            $related->{$key} = $value;
        }
        else {
            Carp::croak qq/Unknown column '$key'/;
        }
    }

    my $sql = ObjectDB::SQL::Insert->new;
    $sql->table($class->schema->table);
    $sql->columns([keys %$columns]);
    $sql->driver($dbh->{Driver}->{Name});

    my $self = $class->new;
    $self->_dbh($dbh);
    $self->column(%$columns);

    return $self->txn(sub {
        warn "$sql" if DEBUG;

        my $sth = $dbh->prepare("$sql");
        return unless $sth;

        my $rv = $sth->execute(values %$columns);
        return unless $rv && $rv eq '1';

        $self->is_in_db(1);

        if (my $auto_increment = $class->schema->auto_increment) {
            my $id =
              $dbh->last_insert_id(undef, undef, $class->schema->table,
                $auto_increment);
            $self->column($auto_increment => $id);
        }

        $self->is_modified(0);

        while (my ($key, $value) = each %$related) {
            $self->{related}->{$key} = $self->create_related($key => $value);
        }

        return $self;
    });
}

sub create_related {
    my $self = shift;
    my $name = shift;
    my $data = shift;

    my $dbh = $self->_dbh;

    my $rel = $self->schema->relationship($name);

    my ($from, $to) = %{$rel->map};

    my @params = ($to => $self->column($from));

    push @params, @{$rel->where} if $rel->where;

    if (ref $data eq 'ARRAY' && $rel->type ne 'has_many') {
        Carp::croak qq/Relationship is not multiple/;
    }

    my $wantarray = wantarray;
    return $self->txn(sub {
        if ($rel->type eq 'has_many') {
            my $result;
            $data = [$data] unless ref $data eq 'ARRAY';
            foreach my $d (@$data) {
                push @$result, $rel->foreign_class->create(dbh => $dbh, %$d, @params);
            }

            return $wantarray ? @$result : $result;
        }
        else {
            return $self->{related}->{$name} = $rel->foreign_class->create(dbh => $dbh, %$data, @params);
        }
    });
}

sub delete_related {
    my $self = shift;
    my $name = shift;
    my %params = @_;

    my $rel = $self->schema->relationship($name);

    Carp::croak qq/Action on this relationship type is not supported/
      unless $rel->type =~ m/^(?:has_one|has_many)$/;

    my $dbh = $self->_dbh;

    my ($from, $to) = %{$rel->map};

    my @params = ($to => $self->column($from));

    push @params, @{$rel->where} if $rel->where;

    push @params, @{delete $params{where}} if $params{where};

    delete $self->{related}->{$name};

    return $rel->foreign_class->delete(dbh => $dbh, where => [@params], %params);
}

sub related {
    my $self = shift;
    my $name = shift;

    my $rel = $self->schema->relationship($name);

    my $related = $self->{related}->{$name};
    return $related if $related;

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
    my $class = shift;
    my %params = @_;

    my $dbh = delete $params{dbh} || $class->dbh;
    Carp::croak qq/dbh is required/ unless $dbh;

    $class->schema->build($dbh);

    my $single = $params{first} || $params{single} ? 1 : 0;

    my $sql = ObjectDB::SQL::Select->new;
    $sql->source($class->schema->table);

    my @columns;
    if (my $id = delete $params{id}) {
        @columns = @{$class->schema->columns};
        $sql->columns([@columns]);
        $sql->where($class->schema->primary_keys->[0] => $id);
        $single = 1;
    }
    else {
        @columns = @{$class->schema->columns};
        Carp::croak qq/Schema has no columns/ unless @columns;
        #use Data::Dumper;
        $sql->columns([@columns]);

        #warn Dumper $sql;
        if (my $where = $params{where}) {
            $class->_resolve_where(where => $where, sql => $sql);
        }
        #warn Dumper $sql;
    }

    #use Data::Dumper;
    #warn Dumper $params{with};
    if ($params{with}) {
        $class->_resolve_with(with => $params{with}, sql => $sql);
    }
    #warn Dumper $params{with};

    warn "$sql" if DEBUG;

    my $sth = $dbh->prepare("$sql");
    return unless $sth;

    my $rv = $sth->execute(@{$sql->bind});
    return unless $rv;

    if (wantarray) {
        my $rows = $sth->fetchall_arrayref;
        return () unless $rows && @$rows;

        my @result;
        foreach my $row (@$rows) {
            push @result,
              $class->_row_to_object(
                dbh  => $dbh,
                row  => $row,
                sql  => $sql,
                with => $params{with}
              );
        }

        return @result;
    }
    elsif ($single) {
        my $rows = $sth->fetchall_arrayref;
        return unless $rows && @$rows;

        return $class->_row_to_object(dbh => $dbh, row => $rows->[0],
            sql => $sql, with => $params{with});
    }
    else {
        return ObjectDB::Iterator->new(
            cb => sub {
                my @row = $sth->fetchrow_array;
                return unless @row;

                return $class->_row_to_object(
                    dbh  => $dbh,
                    row  => [@row],
                    sql  => $sql,
                    with => $params{with}
                );
            }
        );
    }
}

sub find_related {
    my $self = shift;
    my $name = shift;
    my %params = @_;

    my $dbh = $self->_dbh;

    my $rel = $self->schema->relationship($name);

    my ($from, $to) = %{$rel->map};

    my @where = ($to => $self->column($from));

    push @where, @{$rel->where} if $rel->where;
    push @where, @{delete $params{where}} if $params{where};

    $params{first} = 1 if $rel->type =~ m/belongs_to/;

    return $rel->foreign_class->find(dbh => $dbh, where => [@where], %params);
}

sub update_column {
    my $self = shift;

    $self->column(@_);

    return $self->update;
}

sub update {
    my $self = shift;
    my %params = @_;

    my $dbh = delete $params{dbh} || $self->_dbh || $self->dbh;

    Carp::croak qq/dbh is required/ unless $dbh;

    if ($self->is_modified) {
        Carp::croak "->update: no primary or unique keys specified"
          unless $self->_are_primary_keys_set;

        my @columns =
          grep { !$self->schema->is_primary_key($_) } $self->columns;
        my @values = map { $self->column($_) } @columns;

        my $sql = ObjectDB::SQL::Update->new;
        $sql->table($self->schema->table);
        $sql->columns(\@columns);
        $sql->bind(\@values);
        $sql->where(map { $_ => $self->column($_) } @{$self->schema->primary_keys});

        warn "$sql" if DEBUG;

        my $sth = $dbh->prepare("$sql");
        return unless $sth;

        my $rv = $sth->execute(@{$sql->bind});
        return unless $rv && $rv eq '1';

        $self->is_in_db(1);
        $self->is_modified(0);
    }

    return $self;
}

sub delete {
    my $self = shift;
    my %params = @_;

    my $dbh = delete $params{dbh} || (ref($self) && $self->_dbh) || $self->dbh;

    if (ref($self) && !%params) {
        Carp::croak "->delete: no primary or unique keys specified"
          unless $self->_are_primary_keys_set;

        return $self->txn(sub {
            my @child_rel = $self->schema->child_relationships;
            foreach my $name (@child_rel) {
                my $related = $self->find_related($name);
                while (my $r = $related->next) {
                    $r->delete(dbh => $dbh);
                }
            }

            my @columns = $self->columns;
            my @keys = grep { $self->schema->is_primary_key($_) } @columns;
            @keys = grep { $self->schema->is_unique_key($_) } @columns unless @keys;

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
        });
    }
    else {
        return $self->txn(dbh => $dbh, sub {
            my $found = $self->find(dbh => $dbh, %params);
            while (my $r = $found->next) {
                $r->delete(dbh => $dbh);
            }

            return 1;
        });
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
    my $class = shift;
    my %params = @_;

    my $where = $params{where};
    my $sql  = $params{sql};

    return unless $where && @$where;

    for (my $i = 0; $i < @$where; $i += 2) {
        my $key = $where->[$i];
        my $value = $where->[$i + 1];

        if ($key =~ m/\./) {
            my $parent = $class;
            my $source;
            while ($key =~ s/(\w+)\.//) {
                my $name = $1;
                my $rel = $parent->schema->relationship($name);

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
    my $class = shift;
    my %params = @_;

    my $with = $params{with};
    my $sql  = $params{sql};

    return unless $with;

    $with = [$with] unless ref $with eq 'ARRAY';
    $with = $class->_fix_with($with);

    use Data::Dumper;

    foreach my $name (@$with) {
        my @names = split /\./ => $name;
        my $parent = $class;
        while (my $name = shift @names) {
            my $rel = $parent->schema->relationship($name);

            $sql->source($rel->to_source);
            $sql->columns($rel->foreign_class->schema->columns);

            $parent = $rel->foreign_class;
        }
    }

    #die Dumper $sql;
}

sub _fix_with {
    my $class = shift;
    my $with = shift;

    my $parts = {};
    foreach my $rel (@$with) {
        while ($rel =~ s/^(\w+)\.?//) {
            my $parent = $1;
            $parts->{$parent} = 1;
            while ($rel =~ s/^(\w+)\.?//) {
                $parent .= '.' . $1;
                $parts->{$parent} = 1;
            }
        }
    }

    return [sort keys %$parts];
}

sub _are_primary_keys_set {
    my $self = shift;

    my @ok = grep {
        $self->schema->is_primary_key($_) or $self->schema->is_unique_key($_)
    } $self->columns;

    return @ok ? 1 : 0;
}

sub _row_to_object {
    my $class = shift;
    my %params = @_;

    my $dbh = $params{dbh};
    my $row = $params{row};
    my $sql = $params{sql};
    my $with = $params{with};

    my @columns = $sql->columns;

    my $self = $class->new;
    foreach my $column (@columns) {
        $self->column($column => shift @$row);
    }
    #warn '_row v';
    #warn Dumper $sql;
    #warn Dumper \@columns;
    #warn '_row ^';

    my $sources = [@{$sql->sources}];
    shift @$sources;

    $with = [$with] unless ref $with eq 'ARRAY';
    foreach my $name (@$with) {
        next unless $name;

        my @names = split /\./ => $name;
        my $parent = $self;
        foreach my $name (@names) {
            my $rel = $parent->schema->relationship($name);

            #use Data::Dumper;
            my $object = $rel->foreign_class->new;
            $object->_dbh($dbh);
            #warn Dumper $object->schema;
            my $source = shift @$sources;
            foreach my $column (@{$source->{columns}}) {
                $object->column($column => shift @$row);
            }
            $object->is_modified(0);
            #warn 'v' x 20;
            #die Dumper $object->schema;

            #warn 'SAVE';
            $parent->{related}->{$name} = $object;

            $parent = $rel->foreign_class;
        }
    }

    #use Data::Dumper;
    #warn Dumper $row;
    Carp::croak qq/Not all the rows are mapped to the object/ if @$row;

    #die Dumper $self;

    $self->_dbh($dbh);
    $self->is_in_db(1);
    $self->is_modified(0);

    return $self;
}

1;
