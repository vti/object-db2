package ObjectDB::Remover;

use strict;
use warnings;

use base 'ObjectDB::Base';

use constant DEBUG => $ENV{OBJECTDB_DEBUG} || 0;

use ObjectDB::Finder;
use ObjectDB::SQL::Delete;

sub conn           { $_[0]->{conn} }
sub schema         { $_[0]->{schema} }
sub namespace      { $_[0]->{namespace} }
sub rows_as_object { $_[0]->{rows_as_object} }

sub delete {
    my $self   = shift;
    my %params = @_;

    return $self->_delete_instance unless %params;

    return $self->conn->txn(
        sub {
            my $dbh = shift;

            my $count = 0;
            my $found = $self->_finder->find(%params);
            while (my $r = $found->next) {
                $r->delete;
                $count++;
            }

            return $count;
        }
    );
}

sub delete_related {
    my $self   = shift;
    my $name   = shift;
    my %params = @_;

    my $rel = $self->schema->relationship($name);
    $rel->build($self->conn);

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

        return $rel->map_class->new(conn => $self->conn)->delete(
            where => [$to => $self->{columns}->get($from), @where],
            %params
        );
    }
    else {
        my ($from, $to) = %{$rel->map};

        $self->{related}->delete($name);

        return $rel->foreign_class->new(conn => $self->conn)->delete(
            where => [$to => $self->{columns}->get($from), @where],
            %params
        );
    }
}

sub _delete_instance {
    my $self = shift;

    my @primary_or_unique_key = $self->{columns}->pk_or_uk_columns;

    Carp::croak q/->delete: no primary or unique keys specified/
      unless @primary_or_unique_key;

    my $conn = $self->conn;

    return $conn->txn(
        sub {
            my $dbh = shift;

            my @child_rel = $self->schema->child_relationships;
            foreach my $name (@child_rel) {
                my $rel = $self->schema->relationship($name);
                $rel->build($conn);

                my $related;

                if ($rel->is_has_and_belongs_to_many) {
                    my $map_from = $rel->map_from;

                    my ($to, $from) =
                      %{$rel->map_class->schema->relationship($map_from)
                          ->map};

                    $related =
                      $rel->map_class->new(conn => $conn)
                      ->find(where => [$to => $self->{columns}->get($from)]);
                }
                else {
                    $related = $self->_finder->find_related($name);
                }

                next unless $related;

                while (my $r = $related->next) {
                    $r->delete;
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
    );
}

sub _finder {
    my $self = shift;

    $self->{finder} ||= ObjectDB::Finder->new(
        namespace      => $self->namespace,
        conn           => $self->conn,
        schema         => $self->schema,
        rows_as_object => $self->rows_as_object,
        columns        => $self->{columns},
        related        => $self->{related},
    );

    return $self->{finder};
}

1;
