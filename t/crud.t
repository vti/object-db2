#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 82;

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



### Create ObjectDB::TestData::Hotel and test the created objects
# what makes these tests special?
# - mapping columns do not follow naming conventions
# - mapping columns are not primary key columns
# - multiple columns used to map tables

require "t/test_data/hotel.testdata";
my ($hotel,$hotel2,$hotel3) = ObjectDB::TestData::Hotel->load($conn);

is( @{$hotel->apartments}, 2 );
is( $hotel->apartments->[0]->column('apartment_num_b'), 47 );
is( $hotel->apartments->[0]->column('name'), 'John F. Kennedy' );
is( $hotel->apartments->[0]->column('size'), 78 );

is( $hotel->apartments->[1]->column('apartment_num_b'), 61 );
is( $hotel->apartments->[1]->column('name'), 'George Washington' );
is( $hotel->apartments->[1]->column('size'), 50 );

is( @{$hotel->apartments->[0]->rooms}, 2 );
is( $hotel->apartments->[0]->rooms->[0]->column('room_num_c'), 1);
is( $hotel->apartments->[0]->rooms->[0]->column('size'), 70);
is( $hotel->apartments->[0]->rooms->[1]->column('room_num_c'), 2);
is( $hotel->apartments->[0]->rooms->[1]->column('size'), 8);

is( @{$hotel->apartments->[1]->rooms}, 3 );
is( $hotel->apartments->[1]->rooms->[0]->column('room_num_c'), 1);
is( $hotel->apartments->[1]->rooms->[0]->column('size'), 10);
is( $hotel->apartments->[1]->rooms->[1]->column('room_num_c'), 2);
is( $hotel->apartments->[1]->rooms->[1]->column('size'), 16);
is( $hotel->apartments->[1]->rooms->[2]->column('room_num_c'), 3);
is( $hotel->apartments->[1]->rooms->[2]->column('size'), 70);

# Now the most interesting part:
is( $hotel->apartments->[0]->column('hotel_num_b'), 5 );
is( $hotel->apartments->[1]->column('hotel_num_b'), 5 );

is( $hotel->apartments->[0]->rooms->[0]->column('hotel_num_c'), 5);
is( $hotel->apartments->[0]->rooms->[1]->column('hotel_num_c'), 5);
is( $hotel->apartments->[0]->rooms->[0]->column('apartment_num_c'), 47);
is( $hotel->apartments->[0]->rooms->[1]->column('apartment_num_c'), 47);

is( $hotel->apartments->[1]->rooms->[0]->column('hotel_num_c'), 5);
is( $hotel->apartments->[1]->rooms->[1]->column('hotel_num_c'), 5);
is( $hotel->apartments->[1]->rooms->[2]->column('hotel_num_c'), 5);
is( $hotel->apartments->[1]->rooms->[0]->column('apartment_num_c'), 61);
is( $hotel->apartments->[1]->rooms->[1]->column('apartment_num_c'), 61);
is( $hotel->apartments->[1]->rooms->[2]->column('apartment_num_c'), 61);


ObjectDB::TestData::Hotel->delete($conn);
