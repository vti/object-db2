#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 21;

use lib 't/lib';

use TestDB;

use Author;

my $dbh = TestDB->dbh;

my $author = Author->find(dbh => $dbh, id => 1);
ok(!$author);

$author = Author->create(dbh => $dbh, name => 'foo');
ok($author);
ok($author->is_in_db);
ok(!$author->is_modified);
is_deeply($author->to_hash, {id => $author->id, name => 'foo'});

$author = Author->find(dbh => $dbh, id => $author->id);
ok($author);
ok($author->id);
is($author->column('name'), 'foo');

is_deeply([Author->find(dbh => $dbh, where => [name => 'bar'])], []);

my $i = Author->find(dbh => $dbh);
isa_ok($i, 'ObjectDB::Iterator');
$author = $i->next;
ok($author);
is($author->column('name'), 'foo');
ok(!$i->next);

ok(!Author->find(dbh => $dbh, where => [name => 'bar'], first  => 1));
ok(!Author->find(dbh => $dbh, where => [name => 'bar'], single => 1));

$author->column(name => 'bar');
ok($author->is_modified);
$author->update;
$author = Author->find(dbh => $dbh, id => $author->id);
is($author->column('name'), 'bar');

$author->update_column(name => 'foo');
$author = Author->find(dbh => $dbh, id => $author->id);
is($author->column('name'), 'foo');

ok($author->delete);
ok(!$author->is_in_db);
$author = Author->find(dbh => $dbh, id => $author->id);
ok(!$author);
