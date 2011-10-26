package TestDB;

use strict;
use warnings;

use base 'ObjectDB';

use DBI;

our $DBH;

sub dbh {
    my $class = shift;

    if (@_) {
        $DBH = $_[0];
        return;
    }

    return $DBH if $DBH;

    my @args = ();

    if ($ENV{TEST_DSN}) {
        my @options = split(',', $ENV{TEST_DSN});
        push @args, 'dbi:' . (shift @options) . ':', @options;
    }
    else {
        push @args, 'dbi:SQLite:' . ':memory:';
    }

    my $dbh = DBI->connect(@args);
    die $DBI::errorstr unless $dbh;

    unless ($ENV{TEST_DSN}) {
        $dbh->do("PRAGMA default_synchronous = OFF");
        $dbh->do("PRAGMA temp_store = MEMORY");
    }

    $DBH = $dbh;
    return $dbh;
}

1;
