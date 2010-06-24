#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 27;

use lib 't/lib';

use TestDB;

use Author;
use AuthorAdmin;

my $conn = TestDB->conn;

my $author = Author->find(conn => $conn, id => 999, with => 'author_admin');
ok(!$author, 'unknown id');

$author = Author->create(conn => $conn, name => 'foo', author_admin => {beard => 1});
ok($author, 'create with related object');
ok($author->author_admin, 'related object is saved after creation');
is($author->author_admin->column('beard'), 1, 'related object has right columns');

$author = Author->find(conn => $conn, id => $author->id, with => 'author_admin');
ok($author, 'find with related object');
is($author->column('name'), 'foo', 'object loaded');
ok($author->author_admin, 'related object loaded');
is($author->author_admin->column('beard'), 1, 'related object has right columns');

$author->author_admin->column(beard => 0);
ok($author->author_admin->is_modified, 'related object is modified');
$author->author_admin->update;
$author = Author->find(conn => $conn, id => $author->id, with => 'author_admin');
is($author->author_admin->column('beard'), 0, 'related object is updated');

ok($author->delete_related('author_admin'), 'delete related object');
ok(!$author->author_admin, 'related object is removed');
ok(!AuthorAdmin->find(conn => $conn, id => $author->id), 'related object is not available');

$author->create_related(author_admin => {beard => 0});
ok($author->author_admin, 'create related object');
is($author->author_admin->column('beard'), 0, 'related object is prefetched');

$author = Author->find(conn => $conn, id => $author->id);
my $author_admin = $author->find_related('author_admin')->next;
ok($author_admin, 'related object is prefetched');
is($author_admin->column('beard'), 0, 'related object has right columns');

ok($author->delete, 'delete object');
ok(!Author->find(conn => $conn, id => $author->id), 'object not available');
ok(!AuthorAdmin->find(conn => $conn, id => $author->id), 'related object not available');

Author->create(conn => $conn, name => 'foo', author_admin => {beard => 1});
Author->create(conn => $conn, name => 'bar', author_admin => {beard => 0});
Author->create(conn => $conn, name => 'baz', author_admin => {beard => 1});

my @authors = Author->find(conn => $conn, where => ['author_admin.beard' => 1]);
is(@authors, 2);
ok(!$authors[0]->{related}->{author_admin});
is($authors[0]->author_admin->column('beard'), 1);

@authors = Author->find(conn => $conn, where => ['author_admin.beard' => 0], with => 'author_admin');
is(@authors, 1);
ok($authors[0]->{related}->{author_admin});
is($authors[0]->author_admin->column('beard'), 0);

Author->delete(conn => $conn);
ok(!AuthorAdmin->find(conn => $conn)->next);
