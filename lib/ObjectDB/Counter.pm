package ObjectDB::Counter;

use strict;
use warnings;

use base 'ObjectDB::Base';

use constant DEBUG => $ENV{OBJECTDB_DEBUG} || 0;

use ObjectDB::SQL::Select;

sub schema { $_[0]->{schema} }
sub dbh   { $_[0]->{dbh} }

sub count {
    my $self   = shift;
    my %params = @_;

    my $dbh = $self->dbh;

    $self->schema->build($dbh);

    my $sql = ObjectDB::SQL::Select->new;

    my $table = $self->schema->table;

    $sql->source($table);
    $sql->columns(\q/COUNT(*)/);

    $sql->where(%params);

    warn "$sql" if DEBUG;

    my $hash_ref = $dbh->selectrow_hashref("$sql", {}, @{$sql->bind});
    return unless $hash_ref && ref $hash_ref eq 'HASH';

    my @values = values %$hash_ref;
    return shift @values;
}

1;
