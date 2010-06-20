#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 20;

use lib 't/lib';

use TestDB;

use Author;
use AuthorAdmin;

my $dbh = TestDB->dbh;

my $author = Author->find(dbh => $dbh, id => 999, with => 'author_admin');
ok(!$author, 'unknown id');

$author = Author->create(dbh => $dbh, name => 'foo', author_admin => {beard => 1});
ok($author, 'create with related object');
ok($author->author_admin, 'related object is saved after creation');
is($author->author_admin->column('beard'), 1, 'related object has right columns');

$author = Author->find(dbh => $dbh, id => $author->id, with => 'author_admin');
ok($author, 'find with related object');
is($author->column('name'), 'foo', 'object loaded');
ok($author->author_admin, 'related object loaded');
is($author->author_admin->column('beard'), 1, 'related object has right columns');

$author->author_admin->column(beard => 0);
ok($author->author_admin->is_modified, 'related object is modified');
$author->update;
$author = Author->find(dbh => $dbh, id => $author->id, with => 'author_admin');
is($author->author_admin->column('beard'), 0, 'related object is updated');

ok($author->delete_related('author_admin'), 'delete related object');
ok(!$author->author_admin, 'related object is removed');
ok(!AuthorAdmin->find(dbh => $dbh, id => $author->id), 'related object is not available');

$author->create_related(author_admin => {beard => 0});
ok($author->author_admin, 'create related object');
is($author->author_admin->column('beard'), 0, 'related object is prefetched');

$author = Author->find(dbh => $dbh, id => $author->id);
$author->find_related('author_admin');
ok($author->author_admin, 'related object is prefetched');
is($author->author_admin->column('beard'), 0, 'related object has right columns');

ok($author->delete, 'delete object');
ok(!Author->find(dbh => $dbh, id => $author->id), 'object not available');
ok(!AuthorAdmin->find(dbh => $dbh, id => $author->id), 'related object not available');
