#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 284;

use lib 't/lib';

use TestEnv;
use HotelData;
use AuthorData;

TestEnv->setup;

### Load test data

HotelData->populate;
my ($author, $author2) = AuthorData->populate;

# strict max: find the biggest room of each hotel
# (or in case of same size, the room with the lower id)

my @rooms = Room->new->find(max => {column => 'size', group => 'hotel_num_c'});
is(@rooms,                               3);
is($rooms[0]->column('hotel_num_c'),     5);
is($rooms[0]->column('apartment_num_c'), 47);
is($rooms[0]->column('room_num_c'),      1);
is($rooms[0]->column('size'),            70);

is($rooms[1]->column('hotel_num_c'),     6);
is($rooms[1]->column('apartment_num_c'), 47);
is($rooms[1]->column('room_num_c'),      1);
is($rooms[1]->column('size'),            70);

is($rooms[2]->column('hotel_num_c'),     7);
is($rooms[2]->column('apartment_num_c'), 11);
is($rooms[2]->column('room_num_c'),      1);
is($rooms[2]->column('size'),            71);


# same test, but turn strict off
# find the biggest room of each hotel, in case of multiple rooms
# with same size per hotel, find all these rooms
@rooms =
  Room->new->find(max => {column => 'size', group => 'hotel_num_c', strict => 0});
is(@rooms,                               4);
is($rooms[0]->column('hotel_num_c'),     5);
is($rooms[0]->column('apartment_num_c'), 47);
is($rooms[0]->column('room_num_c'),      1);
is($rooms[0]->column('size'),            70);

is($rooms[1]->column('hotel_num_c'),     5);
is($rooms[1]->column('apartment_num_c'), 61);
is($rooms[1]->column('room_num_c'),      3);
is($rooms[1]->column('size'),            70);

is($rooms[2]->column('hotel_num_c'),     6);
is($rooms[2]->column('apartment_num_c'), 47);
is($rooms[2]->column('room_num_c'),      1);
is($rooms[2]->column('size'),            70);

is($rooms[3]->column('hotel_num_c'),     7);
is($rooms[3]->column('apartment_num_c'), 11);
is($rooms[3]->column('room_num_c'),      1);
is($rooms[3]->column('size'),            71);


# strict min find the smallest room of each hotel
# (or in case of same size, the room with the lower id)
@rooms = Room->new->find(min => {column => 'size', group => 'hotel_num_c'});
is(@rooms,                               3);
is($rooms[0]->column('hotel_num_c'),     5);
is($rooms[0]->column('apartment_num_c'), 47);
is($rooms[0]->column('room_num_c'),      2);
is($rooms[0]->column('size'),            8);

is($rooms[1]->column('hotel_num_c'),     6);
is($rooms[1]->column('apartment_num_c'), 47);
is($rooms[1]->column('room_num_c'),      2);
is($rooms[1]->column('size'),            8);

is($rooms[2]->column('hotel_num_c'),     7);
is($rooms[2]->column('apartment_num_c'), 11);
is($rooms[2]->column('room_num_c'),      2);
is($rooms[2]->column('size'),            7);


# same test, but turn strict off
# find the smallest room of each hotel, in case of multiple rooms
# with same size per hotel, find all these rooms
@rooms =
  Room->new->find(min => {column => 'size', group => 'hotel_num_c', strict => 0});
is(@rooms,                               5);
is($rooms[0]->column('hotel_num_c'),     5);
is($rooms[0]->column('apartment_num_c'), 47);
is($rooms[0]->column('room_num_c'),      2);
is($rooms[0]->column('size'),            8);

is($rooms[1]->column('hotel_num_c'),     6);
is($rooms[1]->column('apartment_num_c'), 47);
is($rooms[1]->column('room_num_c'),      2);
is($rooms[1]->column('size'),            8);

is($rooms[2]->column('hotel_num_c'),     7);
is($rooms[2]->column('apartment_num_c'), 11);
is($rooms[2]->column('room_num_c'),      2);
is($rooms[2]->column('size'),            7);

is($rooms[3]->column('hotel_num_c'),     7);
is($rooms[3]->column('apartment_num_c'), 12);
is($rooms[3]->column('room_num_c'),      4);
is($rooms[3]->column('size'),            7);

is($rooms[4]->column('hotel_num_c'),     7);
is($rooms[4]->column('apartment_num_c'), 12);
is($rooms[4]->column('room_num_c'),      5);
is($rooms[4]->column('size'),            7);


# Multiple grouping columns, find smallest room for each apartment
@rooms =
  Room->new->find(
    min => {column => 'size', group => ['hotel_num_c', 'apartment_num_c']});
is(@rooms,                    6);
is($rooms[0]->column('size'), 8);

is($rooms[1]->column('size'), 10);

is($rooms[2]->column('hotel_num_c'),     6);
is($rooms[2]->column('apartment_num_c'), 47);
is($rooms[2]->column('room_num_c'),      2);
is($rooms[2]->column('size'),            8);

is($rooms[3]->column('size'), 10);

is($rooms[4]->column('size'), 7);

is($rooms[5]->column('size'), 7);


# same test, without strict
@rooms = Room->new->find(
    min => {
        column => 'size',
        group  => ['hotel_num_c', 'apartment_num_c'],
        strict => 0
    }
);
is(@rooms,                    7);
is($rooms[0]->column('size'), 8);

is($rooms[1]->column('size'), 10);

is($rooms[2]->column('size'), 8);

is($rooms[3]->column('size'), 10);

is($rooms[4]->column('size'), 7);

is($rooms[5]->column('size'), 7);

is($rooms[6]->column('hotel_num_c'),     7);
is($rooms[6]->column('apartment_num_c'), 12);
is($rooms[6]->column('room_num_c'),      5);
is($rooms[6]->column('size'),            7);


# strict top 2
# Get the Top 2 rooms per hotel with biggest size
@rooms =
  Room->new->find(max => {column => 'size', group => 'hotel_num_c', top => 2});
is(@rooms,                          6);
is($rooms[0]->column('room_num_c'), 1);
is($rooms[0]->column('size'),       70);
is($rooms[1]->column('room_num_c'), 3);
is($rooms[1]->column('size'),       70);

is($rooms[2]->column('room_num_c'), 1);
is($rooms[2]->column('size'),       70);
is($rooms[3]->column('room_num_c'), 3);
is($rooms[3]->column('size'),       25);

is($rooms[4]->column('room_num_c'), 1);
is($rooms[4]->column('size'),       71);
is($rooms[5]->column('room_num_c'), 3);
is($rooms[5]->column('size'),       25);


# same test without strict
@rooms =
  Room->new->find(
    max => {column => 'size', group => 'hotel_num_c', top => 2, strict => 0});
is(@rooms,                          6);
is($rooms[0]->column('room_num_c'), 1);
is($rooms[0]->column('size'),       70);
is($rooms[1]->column('room_num_c'), 3);
is($rooms[1]->column('size'),       70);

is($rooms[2]->column('room_num_c'), 1);
is($rooms[2]->column('size'),       70);
is($rooms[3]->column('room_num_c'), 3);
is($rooms[3]->column('size'),       25);

is($rooms[4]->column('room_num_c'), 1);
is($rooms[4]->column('size'),       71);
is($rooms[5]->column('room_num_c'), 3);
is($rooms[5]->column('size'),       25);


# now the same test with min, and order_by to up the ante
@rooms = Room->new->find(
    min => {column => 'size', group => 'hotel_num_c', top => 2},
    order_by => 'hotel_num_c asc, size asc, room_num_c desc'
);
is(@rooms,                           6);
is($rooms[0]->column('hotel_num_c'), 5);
is($rooms[0]->column('room_num_c'),  2);
is($rooms[0]->column('size'),        8);
is($rooms[1]->column('hotel_num_c'), 5);
is($rooms[1]->column('room_num_c'),  1);
is($rooms[1]->column('size'),        10);

is($rooms[2]->column('hotel_num_c'), 6);
is($rooms[2]->column('room_num_c'),  2);
is($rooms[2]->column('size'),        8);
is($rooms[3]->column('hotel_num_c'), 6);
is($rooms[3]->column('room_num_c'),  1);
is($rooms[3]->column('size'),        10);

is($rooms[4]->column('hotel_num_c'), 7);
is($rooms[4]->column('room_num_c'),  4);    # second lowest id
is($rooms[4]->column('size'),        7);
is($rooms[5]->column('hotel_num_c'), 7);
is($rooms[5]->column('room_num_c'),  2);    # lowest id
is($rooms[5]->column('size'),        7);


# same test, but strict turned off
@rooms = Room->new->find(
    min => {column => 'size', group => 'hotel_num_c', top => 2, strict => 0},
    order_by => 'hotel_num_c asc, size asc, room_num_c desc'
);

is(@rooms,                           7);
is($rooms[0]->column('hotel_num_c'), 5);
is($rooms[0]->column('room_num_c'),  2);
is($rooms[0]->column('size'),        8);

is($rooms[1]->column('hotel_num_c'), 5);
is($rooms[1]->column('room_num_c'),  1);
is($rooms[1]->column('size'),        10);

is($rooms[2]->column('hotel_num_c'), 6);
is($rooms[2]->column('room_num_c'),  2);
is($rooms[2]->column('size'),        8);

is($rooms[3]->column('hotel_num_c'), 6);
is($rooms[3]->column('room_num_c'),  1);
is($rooms[3]->column('size'),        10);

is($rooms[4]->column('hotel_num_c'), 7);
is($rooms[4]->column('room_num_c'),  5);
is($rooms[4]->column('size'),        7);

is($rooms[5]->column('hotel_num_c'), 7);
is($rooms[5]->column('room_num_c'),  4);
is($rooms[5]->column('size'),        7);

is($rooms[6]->column('hotel_num_c'), 7);
is($rooms[6]->column('room_num_c'),  2);
is($rooms[6]->column('size'),        7);


###### NESTED IN WITH

# Prefetch only the biggest room of each hotel
my @hotels = Hotel->new->find(
    with => [
        'apartments.rooms' =>
          {max => {column => 'size', group => 'hotel_num_c'}}
    ]
);
is(@hotels, 3);

is(@{$hotels[0]->apartments->[0]->rooms},                   1);
is($hotels[0]->apartments->[0]->rooms->[0]->column('size'), 70);

is(@{$hotels[0]->apartments->[1]->rooms}, 0);

is(@{$hotels[1]->apartments->[0]->rooms},                   1);
is($hotels[1]->apartments->[0]->rooms->[0]->column('size'), 70);

is(@{$hotels[1]->apartments->[1]->rooms}, 0);

is(@{$hotels[2]->apartments->[0]->rooms},                   1);
is($hotels[2]->apartments->[0]->rooms->[0]->column('size'), 71);

is(@{$hotels[2]->apartments->[1]->rooms}, 0);


# same test, but now less strict (include all biggest rooms per hotel)
@hotels = Hotel->new->find(
    with => [
        'apartments.rooms' =>
          {max => {column => 'size', group => 'hotel_num_c', strict => 0}}
    ]
);
is(@hotels,                                                 3);
is(@{$hotels[0]->apartments->[0]->rooms},                   1);
is($hotels[0]->apartments->[0]->rooms->[0]->column('size'), 70);

is(@{$hotels[0]->apartments->[1]->rooms}, 1)
  ;    ### a second room with same size is loaded
is($hotels[0]->apartments->[1]->rooms->[0]->column('size'), 70);

is(@{$hotels[1]->apartments->[0]->rooms},                   1);
is($hotels[1]->apartments->[0]->rooms->[0]->column('size'), 70);

is(@{$hotels[1]->apartments->[1]->rooms}, 0);

is(@{$hotels[2]->apartments->[0]->rooms},                   1);
is($hotels[2]->apartments->[0]->rooms->[0]->column('size'), 71);

is(@{$hotels[2]->apartments->[1]->rooms}, 0);


# Prefetch the TWO biggest rooms of each hotel
@hotels = Hotel->new->find(
    with => [
        'apartments.rooms' =>
          {max => {column => 'size', group => 'hotel_num_c', top => 2}}
    ]
);
is(@hotels,                                                 3);
is(@{$hotels[0]->apartments->[0]->rooms},                   1);
is($hotels[0]->apartments->[0]->rooms->[0]->column('size'), 70);

is(@{$hotels[0]->apartments->[1]->rooms},                   1);
is($hotels[0]->apartments->[1]->rooms->[0]->column('size'), 70);

is(@{$hotels[1]->apartments->[0]->rooms},                   1);
is($hotels[1]->apartments->[0]->rooms->[0]->column('size'), 70);

is(@{$hotels[1]->apartments->[1]->rooms},                   1);
is($hotels[1]->apartments->[1]->rooms->[0]->column('size'), 25);

is(@{$hotels[2]->apartments->[0]->rooms},                   1);
is($hotels[2]->apartments->[0]->rooms->[0]->column('size'), 71);

is(@{$hotels[2]->apartments->[1]->rooms},                   1);
is($hotels[2]->apartments->[1]->rooms->[0]->column('size'), 25);


# Prefetch only the 2 smalest rooms of each hotel
@hotels = Hotel->new->find(
    with => [
        'apartments.rooms' =>
          {min => {column => 'size', group => 'hotel_num_c', top => 2}}
    ]
);
is(@hotels,                                                 3);
is(@{$hotels[0]->apartments->[0]->rooms},                   1);
is($hotels[0]->apartments->[0]->rooms->[0]->column('size'), 8);

is(@{$hotels[0]->apartments->[1]->rooms},                   1);
is($hotels[0]->apartments->[1]->rooms->[0]->column('size'), 10);

is(@{$hotels[1]->apartments->[0]->rooms},                   1);
is($hotels[1]->apartments->[0]->rooms->[0]->column('size'), 8);

is(@{$hotels[1]->apartments->[1]->rooms},                   1);
is($hotels[1]->apartments->[1]->rooms->[0]->column('size'), 10);

is(@{$hotels[2]->apartments->[0]->rooms},                   1);
is($hotels[2]->apartments->[0]->rooms->[0]->column('size'), 7);

is(@{$hotels[2]->apartments->[1]->rooms},                   1);
is($hotels[2]->apartments->[1]->rooms->[0]->column('size'), 7);


# same test, but strict turned off
@hotels = Hotel->new->find(
    with => [
        'apartments.rooms' => {
            min => {
                column => 'size',
                group  => 'hotel_num_c',
                top    => 2,
                strict => 0
            }
        }
    ]
);
is(@hotels,                                                 3);
is(@{$hotels[0]->apartments->[0]->rooms},                   1);
is($hotels[0]->apartments->[0]->rooms->[0]->column('size'), 8);

is(@{$hotels[0]->apartments->[1]->rooms},                   1);
is($hotels[0]->apartments->[1]->rooms->[0]->column('size'), 10);

is(@{$hotels[1]->apartments->[0]->rooms},                   1);
is($hotels[1]->apartments->[0]->rooms->[0]->column('size'), 8);

is(@{$hotels[1]->apartments->[1]->rooms},                   1);
is($hotels[1]->apartments->[1]->rooms->[0]->column('size'), 10);

is(@{$hotels[2]->apartments->[0]->rooms},                   1);
is($hotels[2]->apartments->[0]->rooms->[0]->column('size'), 7);

is(@{$hotels[2]->apartments->[1]->rooms},                   2);
is($hotels[2]->apartments->[1]->rooms->[0]->column('size'), 7);
is($hotels[2]->apartments->[1]->rooms->[1]->column('size'), 7);


### MAX/MIN data using relationsships

### EXPERIMENTAL

# now group by criteria that can NOT be found in the same table
# get the 6 latest comments on articles of an author for each author
# note: there is no column in the comments table that allows to group
# directly by author (the existing author_id column contains no data as
# it refers to direct comments on the author, not to comments on articles
# of the author)

# Max top 1, strict mode
my @comments =
  Comment->new->find(
    max => {column => 'creation_date', group => 'article.author.id'},);
is(@comments,                             2);
is($comments[0]->column('creation_date'), '2010-01-01');
is($comments[1]->column('creation_date'), '2011-12-01');


# Max top 2, strict mode
@comments =
  Comment->new->find(max =>
      {column => 'creation_date', group => 'article.author.id', top => 2},);
is(@comments,                             4);
is($comments[0]->column('creation_date'), '2010-01-01');
is($comments[2]->column('content'),       'comment 2-3-1');
is($comments[3]->column('content'),       'comment 2-1-1');


# Max top 3, strict mode (1st author has two articles with same date, both competing for the number 3 spot)
@comments =
  Comment->new->find(max =>
      {column => 'creation_date', group => 'article.author.id', top => 3},);
is(@comments,                             6);
is($comments[0]->column('creation_date'), '2010-01-01');
is($comments[1]->column('creation_date'), '2009-11-21');
is($comments[2]->column('creation_date'), '2008-12-21');
is($comments[2]->column('content'),       'comment 1-1-2');


# Max top 6, strict mode (2nd author has only 2 articles with a total of 3 comments)
# comment no 6 and 7 (no date) compete for higher spot, lower id wins
@comments =
  Comment->new->find(max =>
      {column => 'creation_date', group => 'article.author.id', top => 6},);
is(@comments,                             9);
is($comments[0]->column('creation_date'), '2010-01-01');
is($comments[2]->column('content'),       'comment 1-1-2');
is($comments[5]->column('creation_date'), '2005-12-01');
is($comments[5]->column('content'),       'comment 1-1-1');    # lower id
is($comments[6]->column('content'),       'comment 2-3-1');


### now non strict mode

# Max top 1, non strict mode
@comments =
  Comment->new->find(max =>
      {column => 'creation_date', group => 'article.author.id', strict => 0},
  );
is(@comments,                             2);
is($comments[0]->column('creation_date'), '2010-01-01');
is($comments[1]->column('creation_date'), '2011-12-01');


# Max top 2, non strict mode
@comments = Comment->new->find(
    max => {
        column => 'creation_date',
        group  => 'article.author.id',
        top    => 2,
        strict => 0
    },
);
is(@comments,                             4);
is($comments[0]->column('creation_date'), '2010-01-01');
is($comments[2]->column('content'),       'comment 2-3-1');
is($comments[3]->column('content'),       'comment 2-1-1');


# Max top 3, non strict mode
@comments = Comment->new->find(
    max => {
        column => 'creation_date',
        group  => 'article.author.id',
        top    => 3,
        strict => 0
    },
);
is(@comments,                             7);
is($comments[0]->column('creation_date'), '2010-01-01');
is($comments[1]->column('creation_date'), '2009-11-21');
is($comments[2]->column('creation_date'), '2008-12-21');
is($comments[2]->column('content'),       'comment 1-1-2');
is($comments[3]->column('creation_date'), '2008-12-21');
is($comments[3]->column('content'),       'comment 1-1-4');


# Max top 6, non strict mode
@comments = Comment->new->find(
    max => {
        column => 'creation_date',
        group  => 'article.author.id',
        top    => 6,
        strict => 0
    },
);
is(@comments,                             10);
is($comments[0]->column('creation_date'), '2010-01-01');
is($comments[2]->column('content'),       'comment 1-1-2');
is($comments[7]->column('content'),       'comment 2-3-1');


### now similar tests for min


# Min top 1, strict mode
@comments =
  Comment->new->find(
    min => {column => 'creation_date', group => 'article.author.id'},);
is(@comments,                       2);
is($comments[0]->column('content'), 'comment 1-1-1');
is($comments[1]->column('content'), 'comment 2-1-2');


# Min top 2, strict mode
@comments =
  Comment->new->find(min =>
      {column => 'creation_date', group => 'article.author.id', top => 2},);
is(@comments,                       4);
is($comments[0]->column('content'), 'comment 1-1-1');
is($comments[1]->column('content'), 'comment 1-3-1');
is($comments[2]->column('content'), 'comment 2-1-2');
is($comments[3]->column('content'), 'comment 2-1-1');


# Min top 3, strict mode
@comments =
  Comment->new->find(min =>
      {column => 'creation_date', group => 'article.author.id', top => 3},);
is(@comments,                       6);
is($comments[0]->column('content'), 'comment 1-1-1');
is($comments[1]->column('content'), 'comment 1-3-1');
is($comments[2]->column('content'), 'comment 1-1-6');
is($comments[3]->column('content'), 'comment 2-1-2');
is($comments[4]->column('content'), 'comment 2-1-1');
is($comments[5]->column('content'), 'comment 2-3-1');


# Min top 6, strict mode
@comments =
  Comment->new->find(min =>
      {column => 'creation_date', group => 'article.author.id', top => 6},);
is(@comments,                             9);
is($comments[0]->column('content'),       'comment 1-1-1');
is($comments[5]->column('content'),       'comment 1-1-3');
is($comments[6]->column('content'),       'comment 2-1-2');
is($comments[7]->column('content'),       'comment 2-1-1');
is($comments[7]->column('creation_date'), '2005-07-31');
is($comments[8]->column('content'),       'comment 2-3-1');


# Min top 1, non strict mode
@comments =
  Comment->new->find(min =>
      {column => 'creation_date', group => 'article.author.id', strict => 0},
  );
is(@comments,                       3);
is($comments[0]->column('content'), 'comment 1-1-1');
is($comments[1]->column('content'), 'comment 1-3-1');
is($comments[2]->column('content'), 'comment 2-1-2');


# Min top 2, non strict mode
@comments = Comment->new->find(
    min => {
        column => 'creation_date',
        group  => 'article.author.id',
        top    => 2,
        strict => 0
    },
);
is(@comments,                       4);
is($comments[0]->column('content'), 'comment 1-1-1');
is($comments[1]->column('content'), 'comment 1-3-1');
is($comments[2]->column('content'), 'comment 2-1-2');
is($comments[3]->column('content'), 'comment 2-1-1');


# Min top 6, non strict mode
@comments = Comment->new->find(
    min => {
        column => 'creation_date',
        group  => 'article.author.id',
        top    => 6,
        strict => 0
    },
);
is(@comments,                       9);
is($comments[0]->column('content'), 'comment 1-1-1');
is($comments[6]->column('content'), 'comment 2-1-2');
is($comments[8]->column('content'), 'comment 2-3-1');


##########################################################################
# TO DO: Tests where other parameters are passed (where, with, columns ...)
# to eliminate interactions


HotelData->cleanup;
AuthorData->cleanup;

TestEnv->teardown;
