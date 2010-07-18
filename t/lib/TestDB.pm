package TestDB;

use strict;
use warnings;

use DBI;
use File::Spec;
use ObjectDB::Connector;

my $dbi = 'dbi:SQLite';

#sub _database { File::Spec->catfile(File::Spec->tmpdir, 'object_db.db') }
sub _database {'object_db.db'}

sub db {
    return 'mysql' if $ENV{TEST_MYSQL};
    return 'sqlite';
}

sub cleanup { 
    $ENV{TEST_MYSQL} || unlink(_database()) && return;
}

our $conn;

sub conn {
    my $self = shift;

    return $conn if $conn;

    my @args = ();

    if ($ENV{TEST_MYSQL}) {
        my @options = split(',', $ENV{TEST_MYSQL});
        push @args, 'dbi:mysql:' . shift @options, @options;
    }
    else {
        push @args, 'dbi:SQLite:' . _database();
    }

    $conn = ObjectDB::Connector->new(@args);
    die $DBI::errorstr unless $conn;

    unless ($ENV{TEST_MYSQL}) {
        $conn->run(sub { $_->do("PRAGMA default_synchronous = OFF") });
        $conn->run(sub { $_->do("PRAGMA temp_store = MEMORY") });
    }
    return $conn;
}

1;
