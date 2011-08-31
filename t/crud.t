#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 57;

use lib 't/lib';

use DBI;
use TestEnv;
use TestDB;

TestEnv->setup;

use Author;

my $author = Author->new->find(id => 999);
ok(!$author);

is(Author->new->count, 0);

$author = Author->new->set_columns(name => 'foo')->create;
ok($author);
ok($author->is_in_db);
ok(!$author->is_modified);
is_deeply($author->to_hash, {id => $author->id, name => 'foo'});

is(Author->new->count, 1);

$author = Author->new->find(id => $author->id);
ok($author);
ok($author->id);
is($author->name, 'foo');

$author = Author->new->find(id => $author->id, columns => []);
ok($author);
ok($author->id);
ok(not defined $author->name);

is_deeply([Author->new->find(where => [name => 'bar'])], []);

my $i = Author->new->find;
isa_ok($i, 'ObjectDB::Iterator');
$author = $i->next;
ok($author);
is($author->name, 'foo');
ok(!$i->next);

ok(!Author->new->find(where => [name => 'bar'], first  => 1));
ok(!Author->new->find(where => [name => 'bar'], single => 1));

$author->name('bar');
ok($author->is_modified);
$author->update;
$author = Author->new->find(id => $author->id);
is($author->name, 'bar');

$author->update_column(name => 'foo');
$author = Author->new->find(id => $author->id);
is($author->name, 'foo');

is(Author->new->update(set => [name => 'bar'], where => [name => 'bar']), 0);
$author = Author->new->find(id => $author->id);
ok($author);
is($author->name, 'foo');

is(Author->new->update(set => [name => 'bar'], where => [name => 'foo']), 1);
$author = Author->new->find(id => $author->id);
ok($author);
is($author->name, 'bar');

# Table object
my $author_table = Author->new;
$author_table->update(set => [name => 'foo'], where => [name => 'bar']);
$author = Author->new->find(id => $author->id);
ok($author);
is($author->name, 'foo');

ok($author->delete);
ok(!$author->is_in_db);
$author = Author->new->find(id => $author->id);
ok(!$author);

$author = Author->new->set_columns(name => 'bar')->create;
ok($author);

is(Author->new->count, 1);
is(Author->new->count(name => 'foo'), 0);
is(Author->new->count(name => 'bar'), 1);

is(Author->new->delete(all => 1), 1);
ok(!Author->new->find(id => $author->id));
is(Author->new->count, 0);

Author->new->set_columns(name => 'foo')->create;
Author->new->set_columns(name => 'bar')->create;
Author->new->set_columns(name => 'baz')->create;
is(Author->new->count, 3);
my @authors = Author->new->find(order_by => 'name DESC');
is($authors[0]->name, 'foo');
is($authors[1]->name, 'baz');
is($authors[2]->name, 'bar');

@authors = Author->new->find(limit => 1, order_by => 'name ASC');
is(@authors,          1);
is($authors[0]->name, 'bar');

is(Author->new->delete(all => 1), 3);

$author = Author->new->find_or_create(name => 'foo');
ok($author);
ok($author->id);
is($author->name, 'foo');

my $id = $author->id;
$author = Author->new->find_or_create(name => 'foo');
ok($author);
is($author->id,   $id);
is($author->name, 'foo');

$author = Author->new->find_or_create(name => 'bar');
ok($author);
ok($author->id != $id);
is($author->name, 'bar');

Author->new->delete(all => 1);

TestEnv->teardown;
