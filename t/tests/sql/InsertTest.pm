package InsertTest;

use strict;
use warnings;

use base 'TestSQLBase';

use Test::More;
use TestDB;

use ObjectDB::SQL::Insert;

sub driver {'SQLite'}

sub work_with_default_values : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->table('foo');

    is("$sql", 'INSERT INTO "foo" DEFAULT VALUES');
}

sub accept_columns : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->table('foo');
    $sql->columns([qw/a b c/]);

    is("$sql", 'INSERT INTO "foo" ("a", "b", "c") VALUES (?, ?, ?)');
}

sub _build_sql {
    my $self = shift;

    return ObjectDB::SQL::Insert->new(dbh => TestDB->dbh, @_);
}

1;
