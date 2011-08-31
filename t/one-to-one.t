#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 29;

use lib 't/lib';

use TestEnv;

use Author;
use AuthorAdmin;

TestEnv->setup;

my $author = Author->new->find(id => 999, with => 'author_admin');
ok(!$author, 'unknown id');

$author = Author->new->set_columns(
    name         => 'foo',
    author_admin => {beard => 1}
)->create;
ok($author,               'create with related object');
ok($author->author_admin, 'related object is saved after creation');
is($author->author_admin->column('beard'),
    1, 'related object has right columns');
is_deeply(
    $author->to_hash,
    {   id           => $author->id,
        name         => 'foo',
        author_admin => {author_id => $author->id, beard => 1}
    }
);

$author = Author->new->find(id => $author->id, with => 'author_admin');
ok($author, 'find with related object');
is($author->column('name'), 'foo', 'object loaded');
ok($author->author_admin, 'related object loaded');
is($author->author_admin->column('beard'),
    1, 'related object has right columns');
is_deeply(
    $author->to_hash,
    {   id           => $author->id,
        name         => 'foo',
        password     => '',
        author_admin => {author_id => $author->id, beard => 1}
    }
);

$author->author_admin->column(beard => 0);
ok($author->author_admin->is_modified, 'related object is modified');
$author->author_admin->update;
$author = Author->new->find(id => $author->id, with => 'author_admin');
is($author->author_admin->column('beard'), 0, 'related object is updated');

ok($author->delete_related('author_admin'), 'delete related object');
ok(!$author->author_admin,                  'related object is removed');
ok(!AuthorAdmin->new->find(id => $author->id),
    'related object is not available');

$author->create_related(author_admin => {beard => 0});
ok($author->author_admin, 'create related object');
is($author->author_admin->column('beard'), 0, 'related object is prefetched');

$author = Author->new->find(id => $author->id);
my $author_admin = $author->find_related('author_admin')->next;
ok($author_admin, 'related object is prefetched');
is($author_admin->column('beard'), 0, 'related object has right columns');

ok($author->delete, 'delete object');
ok(!Author->new->find(id => $author->id), 'object not available');
ok(!AuthorAdmin->new->find(id => $author->id),
    'related object not available');

Author->new->set_columns(name => 'foo', author_admin => {beard => 1})->create;
Author->new->set_columns(name => 'bar', author_admin => {beard => 0})->create;
Author->new->set_columns(name => 'baz', author_admin => {beard => 1})->create;

my @authors = Author->new->find(where => ['author_admin.beard' => 1]);
is(@authors,                                   2);
is($authors[0]->author_admin->column('beard'), 1);

@authors = Author->new->find(
    where => ['author_admin.beard' => 0],
    with  => 'author_admin'
);
is(@authors,                                   1);
is($authors[0]->author_admin->column('beard'), 0);

@authors = Author->new->find(
    where => ['author_admin.beard' => 0],
    with  => ['author_admin'       => {columns => 'author_id'}]
);
is(@authors, 1);
ok(not defined $authors[0]->author_admin->column('beard'));

Author->new->delete(all => 1);
ok(!AuthorAdmin->new->find->next);

TestEnv->teardown;
