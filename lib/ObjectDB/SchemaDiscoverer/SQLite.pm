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

    die 'SchemaDiscoverer::SQLite: table \'' . $self->table . '\' not found in DB'
      unless $sql;

    ### TODO: Support for unique keys created by "create unique index"
    ### PRAGMAs index_list and index_info
    ### TODO: cache data in schema files for better cgi performance

    my $counter = 0;
    while ($sql =~ s/UNIQUE\((.*?)\)//) {
        my $unique = $1;
        $unique =~ s / //g;

        my @unique_keys;
        my @uk = split ',' => $unique;
        foreach my $uk (@uk) {
            push @unique_keys, $self->unquote($uk);
        }
        $self->{unique_keys}->[$counter] = [@unique_keys];
        $counter++;
    }

    foreach my $part (split '\n' => $sql) {
        if ($part =~ m/AUTO_?INCREMENT/i) {
            if ($part =~ m/^\s*`(.*?)`/) {
                $self->auto_increment($1);
            }
        }
    }

    my @columns;
    $sth = $dbh->column_info(undef, undef, $self->table, '%');
    while (my $col_info = $sth->fetchrow_hashref) {
        push @columns, $self->unquote($col_info->{COLUMN_NAME});
    }
    $self->columns([sort @columns]);

    my @primary_key;
    $sth = $dbh->primary_key_info(undef, undef, $self->table);
    while (my $col_info = $sth->fetchrow_hashref) {
        push @primary_key, $self->unquote($col_info->{COLUMN_NAME});
    }
    $self->primary_key([@primary_key]);
}

1;
