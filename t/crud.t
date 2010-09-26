#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 53;

use lib 't/lib';

use DBI;
use TestEnv;

TestEnv->setup;

use Author;

my $conn = TestDB->conn;

my $author = Author->find(id => 999);
ok(!$author);

is(Author->count, 0);

$author = Author->create(name => 'foo');
ok($author);
ok($author->is_in_db);
ok(!$author->is_modified);
is_deeply($author->to_hash, {id => $author->id, name => 'foo'});

is(Author->count, 1);

$author = Author->find(id => $author->id);
ok($author);
ok($author->id);
is($author->column('name'), 'foo');

$author = Author->find(id => $author->id, columns => []);
ok($author);
ok($author->id);
ok(not defined $author->column('name'));

is_deeply([Author->find(where => [name => 'bar'])], []);

my $i = Author->find;
isa_ok($i, 'ObjectDB::Iterator');
$author = $i->next;
ok($author);
is($author->column('name'), 'foo');
ok(!$i->next);

ok(!Author->find(where => [name => 'bar'], first  => 1));
ok(!Author->find(where => [name => 'bar'], single => 1));

$author->column(name => 'bar');
ok($author->is_modified);
$author->update;
$author = Author->find(id => $author->id);
is($author->column('name'), 'bar');

$author->update_column(name => 'foo');
$author = Author->find(id => $author->id);
is($author->column('name'), 'foo');

Author->update(set => [name => 'bar'], where => [name => 'bar']);
$author = Author->find(id => $author->id);
ok($author);
is($author->column('name'), 'foo');

Author->update(set => [name => 'bar'], where => [name => 'foo']);
$author = Author->find(id => $author->id);
ok($author);
is($author->column('name'), 'bar');

# Table object
my $author_table = Author->new;
$author_table->update(set => [name => 'foo'], where => [name => 'bar']);
$author = Author->find(id => $author->id);
ok($author);
is($author->column('name'), 'foo');

ok($author->delete);
ok(!$author->is_in_db);
$author = Author->find(id => $author->id);
ok(!$author);

$author = Author->create(name => 'bar');
ok($author);

is(Author->count, 1);
is(Author->count(name => 'foo'), 0);
is(Author->count(name => 'bar'), 1);

Author->delete;
ok(!Author->find(id => $author->id));
is(Author->count, 0);

Author->create(name => 'foo');
Author->create(name => 'bar');
Author->create(name => 'baz');
is(Author->count, 3);
my @authors = Author->find(order_by => 'name DESC');
is($authors[0]->column('name'), 'foo');
is($authors[1]->column('name'), 'baz');
is($authors[2]->column('name'), 'bar');

@authors = Author->find(limit => 1, order_by => 'name ASC');
is(@authors,                    1);
is($authors[0]->column('name'), 'bar');

Author->delete;

$author = Author->find_or_create(name => 'foo');
ok($author);
ok($author->id);
is($author->column('name'), 'foo');

my $id = $author->id;
$author = Author->find_or_create(name => 'foo');
ok($author);
is($author->id,             $id);
is($author->column('name'), 'foo');

$author = Author->find_or_create(name => 'bar');
ok($author);
ok($author->id != $id);
is($author->column('name'), 'bar');

Author->delete;

TestEnv->teardown;
