package TestDB;

use strict;
use warnings;

use DBI;
use File::Spec;

my $dbi = 'dbi:SQLite';

#sub _database { File::Spec->catfile(File::Spec->tmpdir, 'object_db.db') }
sub _database { 'object_db.db' }

sub cleanup { !$ENV{TEST_MYSQL} && unlink _database() }

our $dbh;

sub dbh {
    my $self = shift;

    return $dbh if $dbh;

    my @args = ();

    if ($ENV{TEST_MYSQL}) {
        my @options = split(',', $ENV{TEST_MYSQL});
        push @args, 'dbi:mysql:' . shift @options, @options;
    }
    else {
        push @args, 'dbi:SQLite:' . _database();
    }

    $dbh = DBI->connect_cached(@args);
    die $DBI::errorstr unless $dbh;

    unless ($ENV{TEST_MYSQL}) {
        $dbh->do("PRAGMA default_synchronous = OFF");
        $dbh->do("PRAGMA temp_store = MEMORY");
    }

    return $dbh;
}

1;
