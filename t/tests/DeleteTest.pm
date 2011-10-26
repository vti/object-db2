package DeleteTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use ObjectDB::SQL::Delete;

sub table : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->table('foo');

    is("$sql", "DELETE FROM `foo`");
}

sub with : Test(2) {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->table('foo');
    $sql->where(id => 2);

    is("$sql", "DELETE FROM `foo` WHERE (`id` = ?)");
    is_deeply($sql->bind, [2]);
}

sub _build_sql {
    my $self = shift;

    return ObjectDB::SQL::Delete->new(@_);
}

1;
