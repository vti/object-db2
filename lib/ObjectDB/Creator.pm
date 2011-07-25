package ObjectDB::Creator;

use strict;
use warnings;

use base 'ObjectDB::Base';

use constant DEBUG => $ENV{OBJECTDB_DEBUG} || 0;

use Scalar::Util qw(blessed);

use ObjectDB::Columns;
use ObjectDB::SQL::Insert;

sub schema  { $_[0]->{schema} }
sub conn    { $_[0]->{conn} }
sub columns { $_[0]->{columns} }

sub sql {
    my $self = shift;

    $self->{sql} ||= ObjectDB::SQL::Insert->new;

    return $self->{sql};
}

sub create {
    my $self = shift;

    die
      '->create: primary key column can NOT be NULL or has to be AUTOINCREMENT, table: '
      . $self->schema->table
      unless $self->columns->have_pk_or_ai_columns;

    my $sql = $self->sql;

    $sql->table($self->schema->table);
    $sql->columns([$self->columns->names]);
    $sql->driver($self->conn->driver);

    return $self->conn->txn(
        sub {
            my $dbh = shift;

            my @values = $self->columns->values;

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

                my $rel_object =
                  $self->create_related($name => $value);

                $self->{related}->set($name => $rel_object);
            }

            return $self;
        }
    );
}

sub create_related {
    my $self = shift;
    my ($name, $data) = @_;

    my $rel = $self->schema->relationship($name);
    $rel->build($self->conn);

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
    my $conn      = $self->conn;
    return $conn->txn(
        sub {
            if ($rel->is_has_many) {
                my $result;
                $data = [$data] unless ref $data eq 'ARRAY';
                foreach my $d (@$data) {
                    push @$result,
                      $rel->foreign_class->new(conn => $conn)
                      ->set_columns(%$d, @params)->create;
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
                      $rel->foreign_class->new(conn => $conn)
                      ->find_or_create(%$d);
                    my $rel = $rel->map_class->new(conn => $conn)->set_columns(
                        $from_foreign_pk => $self->{columns}->get($from_pk),
                        $to_foreign_pk   => $object->column($to_pk)
                    )->create;
                }

                # TODO
            }
            else {
                my $rel_object =
                  $rel->foreign_class->new(conn => $conn)
                  ->set_columns(%$data, @params)->create;

                $self->{related}->set($name => $rel_object);

                return $rel_object;
            }
        }
    );
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
