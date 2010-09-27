package ObjectDB::SchemaDiscoverer::mysql;

use strict;
use warnings;

use base 'ObjectDB::SchemaDiscoverer::Base';

sub discover {
    my $self = shift;
    my $dbh  = shift;

    my @columns;

    my $sth = $dbh->column_info(undef, undef, $self->table, '%');

    my $counter = 0;
    while (my $col_info = $sth->fetchrow_hashref) {
        push @columns, $self->unquote($col_info->{COLUMN_NAME});

        $self->auto_increment($columns[$#columns])
          if $col_info->{'mysql_is_auto_increment'};
        $counter++;
    }

    # Throw an exception if table does not exist
    die 'SchemaDiscoverer::mysql: table ' . $self->table . ' not found in DB'
      unless $counter;

    $self->columns([sort @columns]);

    my $result = $dbh->selectall_arrayref(
        'SHOW INDEX FROM ' . $dbh->quote_identifier($self->table),
        {Slice => {}});

    ### TO DO: cache data in schema files for better cgi performance


    # Unique keys
    my @unique_keys_results =
      grep { !$_->{'Non_unique'} && $_->{'Key_name'} ne 'PRIMARY' } @$result;

    my @unique_keys;
    foreach my $result (@unique_keys_results) {
        push @unique_keys, ($result->{'Key_name'}, $result->{'Column_name'});
    }

    my %unique_keys;
    while (@unique_keys) {
        my $key   = shift @unique_keys;
        my $value = shift @unique_keys;

        $unique_keys{$key} ||= [];
        push @{$unique_keys{$key}}, $value;
    }

    my @unique_keys_final;
    $counter = 0;
    foreach my $key (keys %unique_keys) {
        $unique_keys_final[$counter] = $unique_keys{$key};
        $counter++;
    }

    $self->unique_keys(\@unique_keys_final);


    # Primary keys
    my @primary_key =
      map $_->{'Column_name'},
      grep { $_->{'Key_name'} eq 'PRIMARY' } @$result;

    $self->primary_key(\@primary_key);
}

1;
