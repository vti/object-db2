package TestDB;

use strict;
use warnings;

use base 'ObjectDB';

use ObjectDB::Connector;

our $CONN;

sub init_conn {
    my $class = shift;

    return $CONN if $CONN;

    my @args = ();

    if ($ENV{TEST_MYSQL}) {
        my @options = split(',', $ENV{TEST_MYSQL});
        push @args, 'dbi:mysql:' . shift @options, @options;
    }
    else {
        push @args, 'dbi:SQLite:' . ':memory:';
    }

    my $conn = ObjectDB::Connector->new(@args);
    die $DBI::errorstr unless $conn;

    unless ($ENV{TEST_MYSQL}) {
        $conn->run(sub { $_->do("PRAGMA default_synchronous = OFF") });
        $conn->run(sub { $_->do("PRAGMA temp_store = MEMORY") });
    }

    $CONN = $conn;
    return $conn;
}

1;
