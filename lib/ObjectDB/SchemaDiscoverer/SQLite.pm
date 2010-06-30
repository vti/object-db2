package ObjectDB::SchemaDiscoverer::SQLite;

use strict;
use warnings;

use base 'ObjectDB::SchemaDiscoverer::Base';

sub discover {
    my $self = shift;
    my $dbh  = shift;

    my $sth = $dbh->table_info(undef, undef, $self->table);
    my $sql;
    while (my $table_info = $sth->fetchrow_hashref) {
        $sql = $table_info->{sqlite_sql};
        last if $sql;
    }

    if ($sql) {
        my @unique_keys;
        if (my ($unique) = ($sql =~ m/UNIQUE\((.*?)\)/)) {
            my @uk = split ',' => $unique;
            foreach my $uk (@uk) {
                push @unique_keys, $self->unquote($uk);
            }

            $self->unique_keys([@unique_keys]);
        }

        foreach my $part (split '\n' => $sql) {
            if ($part =~ m/AUTO_?INCREMENT/i) {
                if ($part =~ m/^\s*`(.*?)`/) {
                    $self->auto_increment($1);
                }
            }
        }
    }

    my @columns;
    $sth = $dbh->column_info(undef, undef, $self->table, '%');
    while (my $col_info = $sth->fetchrow_hashref) {
        push @columns, $self->unquote($col_info->{COLUMN_NAME});
    }
    $self->columns([@columns]);

    my @primary_keys;
    $sth = $dbh->primary_key_info(undef, undef, $self->table);
    while (my $col_info = $sth->fetchrow_hashref) {
        push @primary_keys, $self->unquote($col_info->{COLUMN_NAME});
    }
    $self->primary_keys([@primary_keys]);
}

1;
