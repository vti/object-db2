package UpdateTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use ObjectDB::SQL::Update;

sub columns_and_values : Test(2) {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->table('foo');
    $sql->columns([qw/ hello boo /]);
    $sql->values([1, 2]);

    is("$sql", "UPDATE `foo` SET `hello` = ?, `boo` = ?");
    is_deeply($sql->bind, [qw/ 1 2 /]);
}

sub with_where : Test(2) {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->table('foo');
    $sql->columns([qw/ hello boo /]);
    $sql->values([5, 9]);
    $sql->where([id => 3]);

    is("$sql", "UPDATE `foo` SET `hello` = ?, `boo` = ? WHERE (`id` = ?)");
    is_deeply($sql->bind, [qw/ 5 9 3 /]);
}

sub values_as_scalarref : Test(2) {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->table('foo');
    $sql->columns([qw/ hello boo /]);
    $sql->values([\'hello + 1', 4]);
    $sql->where([id => 5]);

    is("$sql",
        "UPDATE `foo` SET `hello` = hello + 1, `boo` = ? WHERE (`id` = ?)");
    is_deeply($sql->bind, [qw/ 4 5 /]);
}

sub no_sideeffect : Test(2) {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->table('foo');
    $sql->columns([qw/ hello boo /]);
    $sql->values([\'hello + 1', 4]);
    $sql->where([id => 5]);

    is("$sql",
        "UPDATE `foo` SET `hello` = hello + 1, `boo` = ? WHERE (`id` = ?)");
    is_deeply($sql->bind, [qw/ 4 5 /]);
}

sub _build_sql {
    my $self = shift;

    return ObjectDB::SQL::Update->new(@_);
}

1;
