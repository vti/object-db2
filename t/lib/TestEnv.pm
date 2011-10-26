package TestEnv;

use strict;
use warnings;

use FindBin;
use TestDB;

sub setup {
    shift;

    my $dbh = TestDB->dbh;

    my $driver = $dbh->{'Driver'}->{'Name'};
    return unless $driver eq 'SQLite';

    my $filename;
    if ($driver =~ m/SQLite/) {
        $filename = 'sqlite';
    }
    elsif ($driver =~ m/mysql/) {
        $filename = 'mysql';
    }
    else {
        die "Unknown driver $driver";
    }

    my $fullpath = "$FindBin::Bin/schema/$filename.sql";
    $fullpath = "$FindBin::Bin/../schema/$filename.sql"
      unless -e $fullpath;

    open(my $file, "<$fullpath") or die "Can't open $fullpath: $!";

    my $schema = do { local $/; <$file> };

    my @sql = split(/\s*;\s*/, $schema);

    foreach my $sql (@sql) {
        next unless $sql;

        my ($table) = ($sql =~ m/CREATE\s+TABLE `(.*?)`/i);
        $dbh->do("DROP TABLE IF EXISTS `$table`") if $table;
        $dbh->do($sql);
    }
}

sub teardown {
}

sub clear_table {
    my $self = shift;

    my $dbh = TestDB->dbh;

    foreach my $table (@_) {
        $dbh->do('DELETE FROM ' . $table);
    }
}

1;
