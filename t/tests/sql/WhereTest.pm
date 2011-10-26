package WhereTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use ObjectDB::SQL::Where;

sub cond : Test(2) {
    my $self = shift;

    my $where = $self->_build_where;

    $where->cond(id => 2, title => 'hello');

    is("$where", ' WHERE ("id" = ? AND "title" = ?)');
    is_deeply($where->bind, [qw/ 2 hello /]);
}

sub _build_where {
    my $self = shift;

    return ObjectDB::SQL::Where->new(dbh => TestDB->dbh, @_);
}

1;
