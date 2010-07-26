#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 51;

use lib 't/lib';

use DBI;
use TestDB;

use Author;

my $conn = TestDB->conn;

my $author = Author->find(conn => $conn, id => 999);
ok(!$author);

is(Author->count(conn => $conn), 0);

$author = Author->create(conn => $conn, name => 'foo');
ok($author);
ok($author->is_in_db);
ok(!$author->is_modified);
is_deeply($author->to_hash, {id => $author->id, name => 'foo'});

is(Author->count(conn => $conn), 1);

$author = Author->find(conn => $conn, id => $author->id);
ok($author);
ok($author->id);
is($author->column('name'), 'foo');

$author = Author->find(conn => $conn, id => $author->id, columns => []);
ok($author);
ok($author->id);
ok(not defined $author->column('name'));

is_deeply([Author->find(conn => $conn, where => [name => 'bar'])], []);

my $i = Author->find(conn => $conn);
isa_ok($i, 'ObjectDB::Iterator');
$author = $i->next;
ok($author);
is($author->column('name'), 'foo');
ok(!$i->next);

ok(!Author->find(conn => $conn, where => [name => 'bar'], first  => 1));
ok(!Author->find(conn => $conn, where => [name => 'bar'], single => 1));

$author->column(name => 'bar');
ok($author->is_modified);
$author->update;
$author = Author->find(conn => $conn, id => $author->id);
is($author->column('name'), 'bar');

$author->update_column(name => 'foo');
$author = Author->find(conn => $conn, id => $author->id);
is($author->column('name'), 'foo');

Author->update(conn => $conn, set => [name => 'bar'], where => [name => 'bar']);
$author = Author->find(conn => $conn, id => $author->id);
ok($author);
is($author->column('name'), 'foo');

Author->update(conn => $conn, set => [name => 'bar'], where => [name => 'foo']);
$author = Author->find(conn => $conn, id => $author->id);
ok($author);
is($author->column('name'), 'bar');

ok($author->delete);
ok(!$author->is_in_db);
$author = Author->find(conn => $conn, id => $author->id);
ok(!$author);

$author = Author->create(conn => $conn, name => 'bar');
ok($author);

is(Author->count(conn => $conn), 1);
is(Author->count(conn => $conn, name => 'foo'), 0);
is(Author->count(conn => $conn, name => 'bar'), 1);

Author->delete(conn => $conn);
ok(!Author->find(conn => $conn, id => $author->id));
is(Author->count(conn => $conn), 0);

Author->create(conn => $conn, name => 'foo');
Author->create(conn => $conn, name => 'bar');
Author->create(conn => $conn, name => 'baz');
is(Author->count(conn => $conn), 3);
my @authors = Author->find(conn => $conn, order_by => 'name DESC');
is($authors[0]->column('name'), 'foo');
is($authors[1]->column('name'), 'baz');
is($authors[2]->column('name'), 'bar');

@authors = Author->find(conn => $conn, limit => 1, order_by => 'name ASC');
is(@authors, 1);
is($authors[0]->column('name'), 'bar');

Author->delete(conn => $conn);

$author = Author->find_or_create(conn => $conn, name => 'foo');
ok($author);
ok($author->id);
is($author->column('name'), 'foo');

my $id = $author->id;
$author = Author->find_or_create(conn => $conn, name => 'foo');
ok($author);
is($author->id, $id);
is($author->column('name'), 'foo');

$author = Author->find_or_create(conn => $conn, name => 'bar');
ok($author);
ok($author->id != $id);
is($author->column('name'), 'bar');

Author->delete(conn => $conn);
