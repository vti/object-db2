package SelectTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use ObjectDB::SQL::Select;

sub source : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('foo');
    $sql->columns('foo');

    is("$sql", 'SELECT "foo" FROM "foo"');
}

sub source_as_hashref : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source({name => 'foo', as => 'bar'});
    $sql->columns('foo');

    is("$sql", 'SELECT "foo" FROM "foo" AS "bar"');
}

sub next_source_adds_table_prefix : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('foo');
    $sql->columns('foo');
    $sql->source('bar');
    $sql->columns('bar');

    is("$sql", 'SELECT "foo"."foo", "bar"."bar" FROM "foo", "bar"');
}

sub columns : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('foo');
    $sql->columns('foo');

    is("$sql", 'SELECT "foo" FROM "foo"');
}

sub columns_with_dots : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('foo');
    $sql->columns('foo.bar');

    is("$sql", 'SELECT "foo"."bar" FROM "foo"');
}

sub columns_as_scalarref : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('foo');
    $sql->columns(\'foo AS bar', 'baz');

    is("$sql", 'SELECT foo AS bar, "baz" FROM "foo"');
}

sub columns_as_hashref : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('foo');
    $sql->columns({name => \'foo', as => 'bar'});

    is("$sql", 'SELECT foo AS bar FROM "foo"');
}

sub where : Test(2) {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('foo');
    $sql->columns('foo');
    $sql->where(foo => 1);

    is("$sql", 'SELECT "foo" FROM "foo" WHERE ("foo" = ?)');
    is_deeply($sql->bind, [1]);
}

sub where_as_scalarref : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('foo');
    $sql->columns('foo');
    $sql->where(\"1 > 2");

    is("$sql", 'SELECT "foo" FROM "foo" WHERE (1 > 2)');
}

sub multiple_where : Test(2) {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('foo');
    $sql->columns(qw/foo bar/);
    $sql->where(foo => 1);
    $sql->where(bar => 2);

    is("$sql",
        'SELECT "foo", "bar" FROM "foo" WHERE ("foo" = ? AND "bar" = ?)');
    is_deeply($sql->bind, [1, 2]);
}

sub order_by : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('foo');
    $sql->columns(qw/foo bar/);
    $sql->order_by('foo   ,    bar   DESC');

    is("$sql", 'SELECT "foo", "bar" FROM "foo" ORDER BY "foo", "bar" DESC');
}

sub limit : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('foo');
    $sql->columns(qw/foo bar/);
    $sql->limit(1);

    is("$sql", 'SELECT "foo", "bar" FROM "foo" LIMIT 1');
}

sub offset : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('foo');
    $sql->columns(qw/foo bar/);
    $sql->offset(1);

    is("$sql", 'SELECT "foo", "bar" FROM "foo" OFFSET 1');
}

sub join : Test {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('table1');
    $sql->columns('foo');
    $sql->source(
        {   join => 'inner',
            name => 'table2',
            constraint => ['table1.foo' => \'"table2"."bar"']
        }
    );
    $sql->columns(qw/bar baz/);

    is("$sql",
        'SELECT "table1"."foo", "table2"."bar", "table2"."baz" FROM "table1" INNER JOIN "table2" ON ("table1"."foo" = "table2"."bar")'
    );
}

sub join_with_multi_constraint : Test(2) {
    my $self = shift;

    my $sql = $self->_build_sql;

    $sql->source('table1');
    $sql->columns('foo');
    $sql->source(
        {   join => 'inner',
            name => 'table2',
            constraint =>
              ['table1.foo' => \'"table2"."bar"', 'table1.bar' => 'hello']
        }
    );
    $sql->columns(qw/bar baz/);

    is("$sql",
        'SELECT "table1"."foo", "table2"."bar", "table2"."baz" FROM "table1" INNER JOIN "table2" ON ("table1"."foo" = "table2"."bar" AND "table1"."bar" = ?)'
    );
    is_deeply($sql->bind, ['hello']);
}

sub _build_sql {
    my $self = shift;

    return ObjectDB::SQL::Select->new(dbh => TestDB->dbh, @_);
}

1;
