#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 31;

use lib 't/lib';


use TestEnv;
TestEnv->setup;


use AuthorData;
my ($author1, $author2) = AuthorData->populate;


use HotelData;
my ($hotel1, $hotel2, $hotel3) = HotelData->populate;


# Make sure that data is prefetched
$ENV{OBJECTDB_FORCE_PREFETCH} = 1;


### One primary or unique key column

# Pass primary key as single value
my $author = Author->find(id => $author2->column('id'));
is($author->column('name'), 'author 2');


# Pass primary key as hash ref
$author = Author->find(id => {id => $author2->column('id')});
is($author->column('name'), 'author 2');


# Pass primary key as array ref
$author = Author->find(id => [id => $author2->column('id')]);
is($author->column('name'), 'author 2');


# Pass invalid column (no primary key nor unique key) to throw an exception
ok(!eval { $author = Author->find(id => {password => 'some pass' }) });
my $err_msg = 'FIND: passed columns do not form primary or unique key';
ok($@ =~ m/\Q$err_msg/, "throw exception: $err_msg");


# Pass unique key as hash ref
$author = Author->find(id => {name => 'author 2'});
is($author->column('name'), 'author 2');
is($author->column('id'), $author2->id);


# Pass unique key as array ref
$author = Author->find(id => [name => 'author 2']);
is($author->column('name'), 'author 2');
is($author->column('id'), $author2->id);


# Make sure that where clause is IGNORED
# POSSIBLE ALTERNATIVE: THROW AN EXCEPTION
$author = Author->find(id => $author2->column('id'), where => [ name => 'author 1' ]);
is($author->column('name'), 'author 2');


# With prefetch
$author = Author->find(id => $author2->column('id'), with => [qw/articles articles.comments/]);
is($author->column('name'), 'author 2');
is($author->articles->[0]->column('title'), 'article 2-1');
is($author->articles->[1]->column('title'), 'article 2-2');
is($author->articles->[0]->comments->[0]->column('content'),
    'comment 2-1-1');


### Primary key with multiple columns

# Pass columns that do not form a primary or unique key
ok(!eval { ParkingLot->find(id => {lot_id_1_l=>1, number_of_spots=>2}) });
$err_msg = 'FIND: passed columns do not form primary or unique key';
ok($@ =~ m/\Q$err_msg/, "throw exception: $err_msg");


# Pass primary key consisting of multiple columns as hash ref
my $parking_lot = ParkingLot->find(id => {lot_id_1_l=>'20', lot_id_2_l=>'1'});
is($parking_lot->column('number_of_spots'), 56);


# Pass primary key consisting of multiple columns as array ref
$parking_lot = ParkingLot->find(id => [lot_id_1_l=>'20', lot_id_2_l=>'1']);
is($parking_lot->column('number_of_spots'), 56);


# same test with changed order of columns
$parking_lot = ParkingLot->find(id => [lot_id_2_l=>'1', lot_id_1_l=>'20']);
is($parking_lot->column('number_of_spots'), 56);


# pass invalid values
$parking_lot = ParkingLot->find(id => [lot_id_1_l=>'30', lot_id_2_l=>'1']);
is($parking_lot, undef);


### Unique keys with multiple columns

# Pass columns that do not form a primary or unique key
ok(!eval { Hotel->find(id => {street=>1, name=>2}) });
$err_msg = 'FIND: passed columns do not form primary or unique key';
ok($@ =~ m/\Q$err_msg/, "throw exception: $err_msg");


# Pass unique key consisting of multiple columns as hash ref
my $hotel = Hotel->find(id => {name=>'President2', city=>'London'});
is($hotel->column('city'), 'London');
is($hotel->id, $hotel2->id);


# Pass unique key consisting of multiple columns as array ref
$hotel = Hotel->find(id => [name=>'President2', city=>'London']);
is($hotel->column('name'), 'President2');
is($hotel->id, $hotel2->id);


# same test with changed order of columns
$hotel = Hotel->find(id => [city=>'London', name=>'President2']);
is($hotel->column('name'), 'President2');
is($hotel->id, $hotel2->id);


# use second unique key to get the same results
$hotel = Hotel->find(id => [city=>'London', street=>'Berlin Street']);
is($hotel->column('name'), 'President2');
is($hotel->id, $hotel2->id);


# pass invalid values
$hotel = Hotel->find(id => [city=>'London', street=>'Amsterdam Street']);
is($hotel, undef);



# Allow lazy loading of data
$ENV{OBJECTDB_FORCE_PREFETCH} = 0;

AuthorData->cleanup;

HotelData->cleanup;

TestEnv->teardown;
