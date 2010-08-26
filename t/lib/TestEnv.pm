package TestEnv;

use strict;
use warnings;

use FindBin;
use TestDB;


sub setup {
    shift;

    $ENV{OBJECTDB_NO_DBIX_CONNECTOR} = 1;

    my $conn = TestDB->init_conn;

    my $driver = $conn->driver;

    my $filename;
    if ($driver eq 'SQLite') {
        $filename = 'sqlite';
    }
    elsif ($driver eq 'mysql') {
        $filename = 'mysql';
    }
    else {
        die "Unknown driver $driver";
    }

    my $fullpath = "$FindBin::Bin/schema/$filename.sql";
    $fullpath = "$FindBin::Bin/../schema/$filename.sql" unless -e $fullpath;

    open(my $file, "<$fullpath") or die "Can't open $fullpath: $!";

    my $schema = do { local $/; <$file> };

    my @sql = split(/\s*;\s*/, $schema);

    my $dbh = $conn->dbh;
    foreach my $sql (@sql) {
        next unless $sql;

        my ($table) = ($sql =~ m/CREATE\s+TABLE `(.*?)`/i);
        $dbh->do("DROP TABLE IF EXISTS `$table`") if $table;
        $dbh->do($sql);
    }
}

sub teardown {
}

1;
