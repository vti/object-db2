package ObjectDB::Counter;

use strict;
use warnings;

use base 'ObjectDB::Base';

use constant DEBUG => $ENV{OBJECTDB_DEBUG} || 0;

use ObjectDB::SQL::Select;

sub schema { $_[0]->{schema} }
sub conn   { $_[0]->{conn} }

sub count {
    my $self   = shift;
    my %params = @_;

    my $conn = $self->conn;

    $self->schema->build($conn);

    my $sql = ObjectDB::SQL::Select->new;

    my $table = $self->schema->table;

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

1;
