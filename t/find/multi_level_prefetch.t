#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 325;

use lib 't/lib';

use TestEnv;
TestEnv->setup;


use HotelData;
HotelData->populate;


use AuthorData;
my ($author1, $author2) = AuthorData->populate;


# Make sure that data is prefetched
$ENV{OBJECTDB_FORCE_PREFETCH} = 1;


######################################################################
###### 1. Follow naming conventions
######################################################################

######################################################################
#### 1.1 Main -> One-to-Many --> One-to-Many (--> One-to-Many)

# First simple test
my @authors = Author->find(with => [qw/articles articles.comments/]);
is(@authors,                                    2);
is($authors[0]->articles->[0]->column('title'), 'article 1-1');
is($authors[0]->articles->[1]->column('title'), 'article 1-2');
is($authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment 1-1-1');


# Only data of deepest relationship should be loaded completely
@authors = Author->find(with => [qw/articles.comments/]);
is(@authors, 2);
ok(!defined $authors[0]->articles->[0]->column('title'));
ok(!defined $authors[0]->articles->[1]->column('title'));
is($authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment 1-1-1');
is($authors[0]->articles->[0]->comments->[0]->column('creation_date'),
    '2005-12-01');


# Same test, but only with selected columns
@authors =
  Author->find(with => ['articles.comments', {columns => ['content']}]);
is(@authors, 2);
ok(!defined $authors[0]->articles->[0]->column('title'));
ok(!defined $authors[0]->articles->[1]->column('title'));
is($authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment 1-1-1');
is($authors[0]->articles->[0]->comments->[0]->column('creation_date'), undef);


# Same test, but only with selected column passed as scalar
@authors =
  Author->find(with => ['articles.comments', {columns => 'content'}]);
is(@authors, 2);
ok(!defined $authors[0]->articles->[0]->column('title'));
ok(!defined $authors[0]->articles->[1]->column('title'));
is($authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment 1-1-1');
is($authors[0]->articles->[0]->comments->[0]->column('creation_date'), undef);


# Same test, passing related data in wrong format
# format is not supported by Perl
eval { Author->find(with => [qw/articles.comments {columns=>['content']}/]); };
my $err_msg = 'use: with => ["foo",{...}], not: with => [qw/ foo {...} /]';
ok($@ =~ m/\Q$err_msg/);


# Pass options first
eval {
    @authors =
      Author->find(with => [{columns => ['content']}, 'articles.comments']);
};
$err_msg = 'pass relationship before passing any further options as hashref';
ok($@ =~ m/\Q$err_msg/);


# Mixing the order of relationship chains a bit
@authors = Author->find(with => [qw/articles.comments articles/]);
is(@authors,                                    2);
is($authors[0]->articles->[0]->column('title'), 'article 1-1');
is($authors[0]->articles->[1]->column('title'), 'article 1-2');
is($authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment 1-1-1');


###### Load all columns for each relationship
@authors =
  Author->find(
    with => [qw/articles articles.comments articles.comments.sub_comments/]);
is(@authors,                                    2);
is(@{$authors[0]->articles},                    4);
is($authors[0]->articles->[0]->column('title'), 'article 1-1');
is($authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment 1-1-1');
is($authors[0]->articles->[0]->comments->[1]->column('content'),
    'comment 1-1-2');
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[0]
      ->column('content'),
    'sub comment 1-1-1-1'
);
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[1]
      ->column('content'),
    'sub comment 1-1-1-2'
);
is($authors[0]->articles->[2]->column('title'), 'article 1-3');
is($authors[0]->articles->[2]->comments->[0]->column('content'),
    'comment 1-3-1');


###### Only data of deepest relationship should be loaded completely
@authors = Author->find(with => [qw/articles.comments.sub_comments/]);
is(@authors,                 2);
is(@{$authors[0]->articles}, 4);
ok(not defined $authors[0]->articles->[0]->column('title'));
is(@{$authors[0]->articles->[0]->comments}, 6);
ok(not defined $authors[0]->articles->[0]->comments->[0]->column('content'));
ok(not defined $authors[0]->articles->[0]->comments->[1]->column('content'));
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[0]
      ->column('content'),
    'sub comment 1-1-1-1'
);
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[1]
      ->column('content'),
    'sub comment 1-1-1-2'
);
ok(defined $authors[0]->articles->[1]->comments);
is(@{$authors[0]->articles->[1]->comments}, 0);


######################################################################
#### 1.2 Main -> One-to-many  -> One-to-many (-> One-to-many)
####          -> One-to-many  -> One-to-one
@authors = Author->find(
    with => [
        qw/articles articles.comments articles.comments.sub_comments articles.main_category/
    ]
);
is(@authors,                                    2);
is(@{$authors[0]->articles},                    4);
is($authors[0]->articles->[0]->column('title'), 'article 1-1');
is($authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment 1-1-1');
is($authors[0]->articles->[0]->comments->[1]->column('content'),
    'comment 1-1-2');
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[0]
      ->column('content'),
    'sub comment 1-1-1-1'
);
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[1]
      ->column('content'),
    'sub comment 1-1-1-2'
);
is($authors[0]->articles->[2]->column('title'), 'article 1-3');
is($authors[0]->articles->[2]->comments->[0]->column('content'),
    'comment 1-3-1');
is($authors[0]->articles->[0]->main_category->column('title'),
    'main category 4');


@authors =
  Author->find(
    with => [qw/articles.comments.sub_comments articles.main_category/]);
is(@authors,                 2);
is(@{$authors[0]->articles}, 4);
ok(not defined $authors[0]->articles->[0]->column('title'));
is(@{$authors[0]->articles->[0]->comments}, 6);
ok(not defined $authors[0]->articles->[0]->comments->[0]->column('content'));
ok(not defined $authors[0]->articles->[0]->comments->[1]->column('content'));
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[0]
      ->column('content'),
    'sub comment 1-1-1-1'
);
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[1]
      ->column('content'),
    'sub comment 1-1-1-2'
);
is(@{$authors[0]->articles->[1]->comments}, 0);
is($authors[0]->articles->[0]->main_category->column('title'),
    'main category 4');


@authors =
  Author->find(with => [qw/articles.comments articles.main_category/]);
is(@authors,                 2);
is(@{$authors[0]->articles}, 4);
ok(not defined $authors[0]->articles->[0]->column('title'));
is(@{$authors[0]->articles->[0]->comments}, 6);
is($authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment 1-1-1');
is($authors[0]->articles->[0]->comments->[1]->column('content'),
    'comment 1-1-2');
is(@{$authors[0]->articles->[1]->comments}, 0);
is($authors[0]->articles->[0]->main_category->column('title'),
    'main category 4');


@authors =
  Author->find(
    with => [qw/articles.comments articles.main_category articles/]);
is(@authors,                                    2);
is(@{$authors[0]->articles},                    4);
is($authors[0]->articles->[0]->column('title'), 'article 1-1');
is(@{$authors[0]->articles->[0]->comments},     6);
is($authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment 1-1-1');
is($authors[0]->articles->[0]->comments->[1]->column('content'),
    'comment 1-1-2');
is(@{$authors[0]->articles->[1]->comments}, 0);
is($authors[0]->articles->[0]->main_category->column('title'),
    'main category 4');


######################################################################
#### 1.3 Main -> One-to-one -> One-to-many

my @articles = Article->find(with => [qw/main_category.admin_histories/]);
is($articles[0]->main_category->admin_histories->[0]->column('admin_name'),
    'Andre1');
ok(not defined $articles[0]->main_category->column('title'));


@articles =
  Article->find(with => [qw/main_category main_category.admin_histories/]);
is($articles[0]->main_category->admin_histories->[0]->column('admin_name'),
    'Andre1');
is($articles[0]->main_category->column('title'), 'main category 4');


# article with title article 2-1 has no main category, so subrequest
# should not be performed (empty IN, does not execute in mysql)
@articles = Article->find(
    with  => [qw/main_category.admin_histories/],
    where => [title => 'article 2-1']
);
is($articles[0]->main_category, undef);


######################################################################
#### 1.4 Main -> One-to-many -> One-to-one -> One-to-many

@authors = Author->find(with => [qw/articles.main_category.admin_histories/]);
is( $authors[0]->articles->[0]->main_category->admin_histories->[0]
      ->column('admin_name'),
    'Andre1'
);
ok(not defined $authors[0]->articles->[0]->main_category->column('title'));


#####################################################################
#### 1.5 Main -> One-to-one -> One-to-one -> One-to-many

# Pass specific article id
my $article = Article->find(
    id   => $author1->articles->[2]->column('id'),
    with => [qw/special_report.main_category.admin_histories/]
);
is( $article->special_report->main_category->admin_histories->[0]
      ->column('admin_name'),
    'Andre1'
);
ok(not defined $article->special_report->main_category->column('title'));


######################################################################
#### 1.6 Main -> One-to-many -> One-to-one -> One-to-one -> One-to-many

@authors =
  Author->find(
    with => [qw/articles.special_report.main_category.admin_histories/]);
is( $authors[0]->articles->[2]
      ->special_report->main_category->admin_histories->[0]
      ->column('admin_name'),
    'Andre1'
);
ok( not defined $authors[0]->articles->[2]
      ->special_report->main_category->column('title'));


@authors = Author->find(
    with => [
        qw/articles.special_report.main_category articles.special_report.main_category.admin_histories/
    ]
);
is( $authors[0]->articles->[2]
      ->special_report->main_category->admin_histories->[0]
      ->column('admin_name'),
    'Andre1'
);
is($authors[0]->articles->[2]->special_report->main_category->column('title'),
    'main category 4');



######################################################################
#### 1.7 Main -> One-to-many -> One-to-one -> One-to-one -> One-to-many
####          -> One-to-many -> One-to-many

### mix
@authors = Author->find(
    with => [
        qw/articles.comments articles.special_report.main_category.admin_histories/
    ]
);
is( $authors[0]->articles->[2]
      ->special_report->main_category->admin_histories->[0]
      ->column('admin_name'),
    'Andre1'
);
ok( not defined $authors[0]->articles->[2]
      ->special_report->main_category->column('title'));
ok(not defined $authors[0]->articles->[2]->column('title'));
is($authors[0]->articles->[2]->comments->[0]->column('content'),
    'comment 1-3-1');



######################################################################
#### 1.8 Main -> One-to-one -> One-to-one -> One-to-many
####          -> One-to-many

# Pass specific article id, make sure that later subrequest is performed even
# if first subrequest does not provide any results
$article = Article->find(
    id   => $author1->articles->[3]->column('id'),
    with => [qw/to_do_articles special_report.main_category.admin_histories/]
);
is($article->to_do_articles->[0]->column('to_do'), 'to do 4');

# related object should not exist if no data exists for this object (empty objects not allowed)
ok(not defined $article->special_report);



######################################################################
###### 2. Custom naming
###### Using columns for mapping that do not follow naming conventions
###### Using columns for mapping that are not primary key columns
###### Map tables using multiple columns
######################################################################


######################################################################
#### 2.1 Main -> One-to-many -> One-to-many

# First simple test
# only one apartment has images
my @hotels = Hotel->find(with => [qw/apartments.images/]);
is(@hotels,                                                   3);
is(@{$hotels[0]->apartments->[0]->images},                    0);
is($hotels[0]->apartments->[1]->images->[0]->column('width'), 30);


# every hotel has apartments, every apartment has rooms
# check if all mapping colums are loaded
@hotels = Hotel->find(with => [qw/apartments apartments.rooms/]);

is(@{$hotels[0]->apartments},                              2);
is($hotels[0]->apartments->[0]->column('hotel_num_b'),     5);
is($hotels[0]->apartments->[0]->column('apartment_num_b'), 47);
is($hotels[0]->apartments->[0]->column('name'),            'John F. Kennedy');
is($hotels[0]->apartments->[0]->column('size'),            78);

is($hotels[0]->apartments->[1]->column('hotel_num_b'), 5);
is($hotels[0]->apartments->[1]->column('apartment_num_b'), 61);
is($hotels[0]->apartments->[1]->column('name'), 'George Washington');
is($hotels[0]->apartments->[1]->column('size'), 50);

is(@{$hotels[0]->apartments->[0]->rooms},                         2);
is($hotels[0]->apartments->[0]->rooms->[0]->column('hotel_num_c'),5);
is($hotels[0]->apartments->[0]->rooms->[0]->column('apartment_num_c'), 47);
is($hotels[0]->apartments->[0]->rooms->[0]->column('room_num_c'), 1);
is($hotels[0]->apartments->[0]->rooms->[0]->column('size'),       70);

is($hotels[0]->apartments->[0]->rooms->[1]->column('hotel_num_c'),     5);
is($hotels[0]->apartments->[0]->rooms->[1]->column('apartment_num_c'), 47);
is($hotels[0]->apartments->[0]->rooms->[1]->column('room_num_c'), 2);
is($hotels[0]->apartments->[0]->rooms->[1]->column('size'),       8);

is(@{$hotels[0]->apartments->[1]->rooms},                         3);
is($hotels[0]->apartments->[1]->rooms->[0]->column('hotel_num_c'),     5);
is($hotels[0]->apartments->[1]->rooms->[0]->column('apartment_num_c'), 61);
is($hotels[0]->apartments->[1]->rooms->[0]->column('room_num_c'), 1);
is($hotels[0]->apartments->[1]->rooms->[0]->column('size'),       10);

is($hotels[0]->apartments->[1]->rooms->[1]->column('hotel_num_c'),     5);
is($hotels[0]->apartments->[1]->rooms->[1]->column('apartment_num_c'), 61);
is($hotels[0]->apartments->[1]->rooms->[1]->column('room_num_c'), 2);
is($hotels[0]->apartments->[1]->rooms->[1]->column('size'),       16);

is($hotels[0]->apartments->[1]->rooms->[2]->column('hotel_num_c'),     5);
is($hotels[0]->apartments->[1]->rooms->[2]->column('apartment_num_c'), 61);
is($hotels[0]->apartments->[1]->rooms->[2]->column('room_num_c'), 3);
is($hotels[0]->apartments->[1]->rooms->[2]->column('size'),       70);


# Make sure that columns for mapping are present even if no columns should be loaded
@hotels = Hotel->find(
    columns => [],
    with    => [qw/apartments apartments.rooms/]
);
is($hotels[0]->column('hotel_num_a'), 5);
ok($hotels[0]->column('id'));
ok(not defined $hotels[0]->column('name'));
is(@{$hotels[0]->apartments},             2);
is(@{$hotels[0]->apartments->[0]->rooms}, 2);
is($hotels[0]->apartments->[0]->rooms->[1]->column('size'), 8);


# Make sure that columns for mapping are present even if not all apartment columns are loaded
@hotels = Hotel->find(with => [qw/apartments.rooms/]);
ok($hotels[0]->apartments->[0]->column('id'));
is($hotels[0]->apartments->[0]->column('hotel_num_b'),     5);
is($hotels[0]->apartments->[0]->column('apartment_num_b'), 47);
ok(not defined $hotels[0]->apartments->[0]->column('name'));
is(@{$hotels[0]->apartments},                               2);
is(@{$hotels[0]->apartments->[0]->rooms},                   2);
is($hotels[0]->apartments->[0]->rooms->[0]->column('size'), 70);


my $hotel_id = $hotels[0]->column('id');


# Same test with specific id
my $hotel = Hotel->find(
    id   => $hotel_id,
    with => [qw/apartments.rooms/]
);
ok($hotel->apartments->[0]->column('id'));
is($hotel->apartments->[0]->column('hotel_num_b'),     5);
is($hotel->apartments->[0]->column('apartment_num_b'), 47);
ok(not defined $hotel->apartments->[0]->column('name'));
is(@{$hotel->apartments},                               2);
is(@{$hotel->apartments->[0]->rooms},                   2);
is($hotel->apartments->[0]->rooms->[0]->column('size'), 70);


######################################################################
#### 2.2 Main -> One-to-many -> One-to-many -> One-to-one

# one-to-one after one-to-many to make sure that column aliases work correctly in find_related
# map: rooms.apartment_num_c => maid.apartment_num_c, i.e. same column name for mapping in both tables
@hotels = Hotel->find(with => [qw/apartments apartments.rooms.maid/]);
is($hotels[1]->apartments->[0]->rooms->[0]->maid, undef);
is($hotels[1]->apartments->[1]->rooms->[0]->maid->column('name'), 'Amelie');


######################################################################
#### 2.3 Main -> One-to-one -> One-to-many

@hotels = Hotel->find(with => [qw/manager manager.telefon_numbers/]);
is($hotels[0]->manager->column('name'),        'Lalolu');
is($hotels[0]->manager->column('hotel_num_b'), 5);
is(@{$hotels[0]->manager->telefon_numbers},    2);
is($hotels[0]->manager->telefon_numbers->[0]->column('telefon_number'),
    '123456789');
is($hotels[0]->manager->telefon_numbers->[1]->column('telefon_number'),
    '987654321');
is($hotels[0]->manager->telefon_numbers->[0]->column('manager_num_c'),
    '5555555');
is($hotels[0]->manager->telefon_numbers->[1]->column('manager_num_c'),
    '5555555');


$hotel_id = $hotels[0]->column('id');


# same test with passed id
$hotel = Hotel->find(
    id   => $hotel_id,
    with => [qw/manager manager.telefon_numbers/]
);
is($hotel->manager->column('name'),        'Lalolu');
is($hotel->manager->column('hotel_num_b'), 5);
is(@{$hotel->manager->telefon_numbers},    2);
is($hotel->manager->telefon_numbers->[0]->column('telefon_number'),
    '123456789');
is($hotel->manager->telefon_numbers->[1]->column('telefon_number'),
    '987654321');
is($hotel->manager->telefon_numbers->[0]->column('manager_num_c'), '5555555');
is($hotel->manager->telefon_numbers->[1]->column('manager_num_c'), '5555555');


# same test, but do not load manager data
@hotels = Hotel->find(with => [qw/manager.telefon_numbers/]);
ok(not defined $hotels[0]->manager->column('name'));
ok($hotels[0]->manager->column('id'));
is($hotels[0]->manager->column('hotel_num_b'),   5);
is($hotels[0]->manager->column('manager_num_b'), 5555555);
is(@{$hotels[0]->manager->telefon_numbers},      2);
is($hotels[0]->manager->telefon_numbers->[0]->column('telefon_number'),
    '123456789');
is($hotels[0]->manager->telefon_numbers->[1]->column('telefon_number'),
    '987654321');
is($hotels[0]->manager->telefon_numbers->[0]->column('manager_num_c'),
    '5555555');
is($hotels[0]->manager->telefon_numbers->[1]->column('manager_num_c'),
    '5555555');


######################################################################
#### 2.4 Main -> One-to-one -> One-to-one

my @rooms = Room->find(with => [qw/ apartment apartment.hotel /]);
is(@rooms,                                      17);
is($rooms[0]->column('size'),                   70);
is($rooms[0]->apartment->hotel->column('name'), 'President');
is($rooms[7]->column('size'),                   10);
is($rooms[7]->apartment->hotel->column('name'), 'President2');


######################################################################
#### 2.5 Main -> One-to-many -> One-to-many
####                         -> One-to-many

# different mapping columns
# {hotel_num_b => 'hotel_num_c', apartment_num_b => 'apartment_num_c'}
# {image_num_b => 'image_num_c'
@hotels = Hotel->find(with => [qw/apartments.rooms apartments.images/]);
is(@hotels,                                                   3);
is(@{$hotels[0]->apartments->[1]->images},                    1);
is($hotels[0]->apartments->[1]->images->[0]->column('width'), 30);
is(@{$hotels[0]->apartments->[0]->rooms},                     2);
is($hotels[0]->apartments->[0]->rooms->[0]->column('size'),   70);


######################################################################
#### 2.6 Main -> One-to-one -> One-to-many
####                        -> One-to-many

# same mapping columns
# {hotel_num_b => 'hotel_num_c', manager_num_b => 'manager_num_c'}
@hotels =
  Hotel->find(with => [qw/manager.telefon_numbers manager.secretaries/]);
is(@hotels,                                 3);
is($hotels[0]->manager->column('name'),     undef);
is(@{$hotels[0]->manager->telefon_numbers}, 2);
is($hotels[0]->manager->telefon_numbers->[0]->column('telefon_number'),
    123456789);
is($hotels[1]->manager->telefon_numbers->[1]->column('telefon_number'),
    987654329);
is(@{$hotels[0]->manager->secretaries},                         2);
is($hotels[0]->manager->secretaries->[0]->column('first_name'), 'First1');
is($hotels[0]->manager->secretaries->[1]->column('last_name'),  'Last2');
is(@{$hotels[1]->manager->secretaries},                         0);


######################################################################
#### 2.7 Main -> One-to-many
####             One-to-many

# same mapping columns
# {hotel_num_b => 'hotel_num_c', manager_num_b => 'manager_num_c'}
my @managers = Manager->find(with => [qw/telefon_numbers secretaries/]);
is(@managers,                                                    3);
is($managers[0]->column('name'),                                 'Lalolu');
is(@{$managers[0]->telefon_numbers},                             2);
is($managers[0]->telefon_numbers->[0]->column('telefon_number'), 123456789);
is($managers[1]->telefon_numbers->[1]->column('telefon_number'), 987654329);
is(@{$managers[0]->secretaries},                                 2);
is($managers[0]->secretaries->[0]->column('first_name'),         'First1');
is($managers[0]->secretaries->[1]->column('last_name'),          'Last2');
is(@{$managers[1]->secretaries},                                 0);


# similar test, but different mapping columns
# {hotel_num_b => 'hotel_num_c', apartment_num_b => 'apartment_num_c'}
# {image_num_b => 'image_num_c'
my @apartments = Apartment->find(with => [qw/rooms images/]);
is(@apartments,                                  6);
is(@{$apartments[0]->images},                    0);
is(@{$apartments[1]->images},                    1);
is($apartments[1]->images->[0]->column('width'), 30);
is(@{$apartments[0]->rooms},                     2);
is($apartments[0]->rooms->[0]->column('size'),   70);


######################################################################
#### 2.8 Main -> One-to-one -> One-to-one
####                        -> One-to-one

# same mapping columns
# {manager_num_b => 'manager_num_b'}
@hotels = Hotel->find(with => [qw/manager.office manager.car/]);
is(@hotels,                                 3);
is($hotels[0]->manager->column('name'),     undef);
is($hotels[0]->manager->office->column('size'), 33);
is($hotels[0]->manager->car->column('brand'), 'Porsche');
is($hotels[1]->manager->office, undef);
is($hotels[1]->manager->car,  undef);


######################################################################
#### 2.9 Main -> One-to-one
####          -> One-to-one

# same mapping columns
# {manager_num_b => 'manager_num_b'}
@managers = Manager->find(with => [qw/office car/]);
is($managers[0]->office->column('size'), 33);
is($managers[0]->car->column('brand'), 'Porsche');
is($managers[1]->office, undef);
is($managers[1]->car,  undef);


######################################################################
#### 2.10 Create a really complex test

# Main -> One-to-One  -> One-to-one  -> One-to-one (TO DO)
#      |              |              -> One-to-one (TO DO)
#      |              |              -> One-to-many (TO DO)
#      |              |              -> One-to-many (TO DO)
#      |              -> One-to-one
#      |              -> One-to-many
#      |              -> One-to-many
#      -> One-to-One
#      -> One-to-Many -> One-to-many
#      -> One-to-Many


# Hotel -> manager     -> car         -> car_brand (TO DO)
#       |              |              -> car_radio (TO DO)
#       |              |              -> car_maintenance (TO DO)
#       |              |              -> car_wheels (TO DO)
#       |              -> office
#       |              -> telefon_numbers
#       |              -> secretaries
#       -> parking_lot
#       -> apartments -> rooms
#       -> employees


@hotels = Hotel->find(with => [
    'manager',
    'manager.car',
    'manager.office',
    'manager.telefon_numbers',
    'manager.secretaries',
    'parking_lot',
    'apartments',
    'apartments.rooms',
    'employees'
]);

# Hotel
is(@hotels, 3);
is($hotels[0]->column('name'), 'President');
is($hotels[1]->column('name'), 'President2');

# Manager
is($hotels[0]->manager->column('name'),'Lalolu');
is($hotels[1]->manager->column('name'),'Lalolu');

# Car
is(ref $hotels[0]->manager->car, 'Car');
is($hotels[0]->manager->car->column('brand'), 'Porsche');
is($hotels[1]->manager->car, undef);

# Office
is(ref $hotels[0]->manager->office, 'Office');
is($hotels[0]->manager->office->column('size'), '33');
is($hotels[1]->manager->office, undef);

# TelefonNumber
is(@{$hotels[0]->manager->telefon_numbers}, 2);
is($hotels[0]->manager->telefon_numbers->[1]->column('telefon_number'),
    '987654321');
is(@{$hotels[1]->manager->telefon_numbers}, 2);
is($hotels[1]->manager->telefon_numbers->[1]->column('telefon_number'),
    '987654329');

# Secretary
is(@{$hotels[0]->manager->secretaries}, 2);
is($hotels[0]->manager->secretaries->[1]->column('last_name'),
    'Last2');
is(@{$hotels[1]->manager->secretaries}, 0);

# Parking lot
is(ref $hotels[0]->parking_lot, 'ParkingLot');
is($hotels[0]->parking_lot->column('number_of_spots'), 40);
is(ref $hotels[1]->parking_lot, 'ParkingLot');
is($hotels[1]->parking_lot->column('number_of_spots'), 56);
is($hotels[2]->parking_lot, undef);

# Apartment
is(@{$hotels[0]->apartments},2);
is($hotels[0]->apartments->[1]->column('name'), 'George Washington');

is(@{$hotels[1]->apartments},2);
is($hotels[1]->apartments->[1]->column('name'), 'George Washington');

# Room
is(@{$hotels[0]->apartments->[1]->rooms}, 3);
is($hotels[0]->apartments->[1]->rooms->[1]->column('size'), 16);

is(@{$hotels[1]->apartments->[1]->rooms}, 3);
is($hotels[1]->apartments->[1]->rooms->[1]->column('size'), 15);

# Employee
is(@{$hotels[0]->employees},2);
is($hotels[0]->employees->[1]->column('first_name'), 'F2');
is(@{$hotels[1]->employees},0);



######################################################################
###### 3. include "where" parameter in "with" to only prefetch data
###### that meets certain criteria
######################################################################


# has_many relationship
@hotels =
  Hotel->find(
    with => ['apartments.rooms' => {where => [size => 70]}, 'apartments']);
is(@hotels,                               3);
is(@{$hotels[0]->apartments},             2);
is(@{$hotels[1]->apartments},             2);
is(@{$hotels[2]->apartments},             2);
is(@{$hotels[0]->apartments->[0]->rooms}, 1);
is(@{$hotels[0]->apartments->[1]->rooms}, 1);
is(@{$hotels[1]->apartments->[0]->rooms}, 1);
is(@{$hotels[1]->apartments->[1]->rooms}, 0);
is(@{$hotels[2]->apartments->[0]->rooms}, 0);
is(@{$hotels[2]->apartments->[1]->rooms}, 0);


# has_many relationship
@hotels = Hotel->find(
    with => [
        'apartments.rooms' => {where => [size => 70]},
        'apartments'       => {where => [name => 'John F. Kennedy']}
    ]
);
is(@hotels,                               3);
is(@{$hotels[0]->apartments},             1);
is(@{$hotels[1]->apartments},             1);
is(@{$hotels[2]->apartments},             1);
is(@{$hotels[0]->apartments->[0]->rooms}, 1);
is(@{$hotels[1]->apartments->[0]->rooms}, 1);
is(@{$hotels[2]->apartments->[0]->rooms}, 0);


# multi-level where
@hotels =
  Hotel->find(with => ['apartments' => {where => ['rooms.size' => 15]}]);
is(@hotels,                                                3);
is(@{$hotels[0]->apartments},                              0);
is(@{$hotels[1]->apartments},                              1);
is($hotels[1]->apartments->[0]->column('apartment_num_b'), 61);
is(@{$hotels[2]->apartments},                              1);
is($hotels[2]->apartments->[0]->column('apartment_num_b'), 12);


# Similar test, but now LOOKING FOR ROOMS THAT HAVE SAME SIZE IN 2nd APARTMENT
@hotels =
  Hotel->find(with => ['apartments' => {where => ['rooms.size' => 7]}]);
is(@hotels,                   3);
is(@{$hotels[0]->apartments}, 0);
is(@{$hotels[1]->apartments}, 0);
is(@{$hotels[2]->apartments}, 2);    # only 2 apartments (in sql: 3 rows)
is($hotels[2]->apartments->[0]->column('apartment_num_b'), 11);
is($hotels[2]->apartments->[1]->column('apartment_num_b'), 12);


# has_one relationship
@hotels = Hotel->find(with => ['manager' => {where => [name => 'Lalolu']}]);
is(@hotels,                             3);
is($hotels[0]->manager->column('name'), 'Lalolu');
is($hotels[1]->manager->column('name'), 'Lalolu');
is($hotels[2]->manager,                 undef);


######################################################################
###### 4. where and multi-level-with
######################################################################


# No match at all
@hotels = Hotel->find(
    with => [qw/manager manager.telefon_numbers apartments apartments.rooms/],
    where => ['manager.name' => 'Smith2']
);
is(@hotels, 0);


# One match
@hotels = Hotel->find(
    with => [qw/manager manager.telefon_numbers apartments apartments.rooms/],
    where => ['manager.name' => 'Smith']
);
is(@hotels,                             1);
is($hotels[0]->manager->column('name'), 'Smith');
is($hotels[0]->manager->telefon_numbers->[0]->column('telefon_number'),
    '12121212');
is(@{$hotels[0]->apartments},                   2);
is($hotels[0]->apartments->[0]->column('name'), 'John F. Kennedy');
is($hotels[0]->apartments->[0]->rooms->[0]->column('size'), 71);


# One matching hotel, "with" dominates "where" (so all apartments
# with all rooms are loaded for the matching hotel (where
# condition does not apply to subrequests for apartments and rooms)
@hotels = Hotel->find(
    with => [qw/manager manager.telefon_numbers apartments apartments.rooms/],
    where => ['apartments.rooms.size' => 71]
);
is(@hotels,                             1);
is($hotels[0]->manager->column('name'), 'Smith');
is($hotels[0]->manager->telefon_numbers->[0]->column('telefon_number'),
    '12121212');
is(@{$hotels[0]->apartments},                   2);
is($hotels[0]->apartments->[0]->column('name'), 'John F. Kennedy');
is(@{$hotels[0]->apartments->[0]->rooms},       2);
is($hotels[0]->apartments->[0]->rooms->[0]->column('size'), 71);


# Similar test, but now two matching hotels
@hotels = Hotel->find(
    with => [qw/manager manager.telefon_numbers apartments apartments.rooms/],
    where => ['apartments.rooms.size' => 10]
);
is(@hotels,                             2);
is($hotels[0]->column('hotel_num_a'),   5);
is($hotels[1]->column('hotel_num_a'),   6);
is($hotels[0]->manager->column('name'), 'Lalolu');
is($hotels[0]->manager->telefon_numbers->[1]->column('telefon_number'),
    '987654321');
is(@{$hotels[0]->apartments},                   2);
is($hotels[0]->apartments->[0]->column('name'), 'John F. Kennedy');
is(@{$hotels[0]->apartments->[0]->rooms},       2);
is($hotels[0]->apartments->[0]->rooms->[0]->column('size'), 70);


# Similar test, but now LOOKING FOR ROOMS WITH SAME SIZE IN ONE HOTEL
@hotels = Hotel->find(
    with => [qw/manager manager.telefon_numbers apartments apartments.rooms/],
    where => ['apartments.rooms.size' => 70]
);
is(@hotels, 2);    ### should still be 2, not 3 as in sql (left join)
is($hotels[0]->column('hotel_num_a'),     5);
is($hotels[1]->column('hotel_num_a'),     6);
is(@{$hotels[0]->apartments},             2);
is(@{$hotels[1]->apartments},             2);
is(@{$hotels[0]->apartments->[0]->rooms}, 2);
is(@{$hotels[0]->apartments->[1]->rooms}, 3);
is(@{$hotels[1]->apartments->[0]->rooms}, 2);
is(@{$hotels[1]->apartments->[1]->rooms}, 3);


# where: one-to-one -> one-to-one
@rooms = Room->find(
    with  => [qw/ apartment apartment.hotel /],
    where => ['apartment.hotel.name' => 'President']
);
is(@rooms,                                      5);
is($rooms[3]->column('size'),                   16);
is($rooms[3]->apartment->column('name'),        'George Washington');
is($rooms[3]->apartment->hotel->column('name'), 'President');


######################################################################
### FAILING TEST: Putting the same table in different parts of the object hierarchy
#@articles =
#  Article->find(
#    with => [qw/main_category special_report.main_category.admin_histories/]);
#is( $articles[2]->special_report->main_category->admin_histories->[0]->column('admin_name'), 'Andre1');


# Allow lazy loading of data
$ENV{OBJECTDB_FORCE_PREFETCH} = 0;


HotelData->cleanup;
AuthorData->cleanup;
TestEnv->teardown;
