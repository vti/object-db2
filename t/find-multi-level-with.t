#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 161;

use lib 't/lib';

use DBI;
use TestDB;


my $conn = TestDB->conn;

use TestDB;
use Author;
use Article;
use MainCategory;
use Comment;
use SubComment;

use Hotel;


# Create data
my $author = Author->create(
    conn     => $conn,
    name     => 'foo',
    articles => [
        {   title    => 'article title1',
            comments => [
                {content => 'comment content first'},
                {content => 'comment content second'}
            ]
        },
        {   title    => 'article title2'},
        {   title    => 'article title3',
            comments => [{content => 'comment content3'}]
        },
        {   title    => 'article title4',
            to_do_articles => [{to_do => 'to do 4'}]
        }
    ]
);

my $category_1 = MainCategory->create(conn=>$conn, title => 'main category 1');
my $category_2 = MainCategory->create(conn=>$conn, title => 'main category 2');
my $category_3 = MainCategory->create(conn=>$conn, title => 'main category 3');
my $category_4 = MainCategory->create(conn=>$conn, title => 'main category 4');
$author->articles->[0]->column( 'main_category_id' => $category_4->column('id') )->update;

$category_4->create_related('admin_histories',
  { admin_name=>'Andre1', from => '2010-01-01', till => '2010-02-01' } );
$category_4->create_related('admin_histories',
  { admin_name=>'Andre2', from => '2010-02-01', till => '2010-03-01' } );


# 3rd article -> belongs to special report 1 -> belongs to main category 4
my $special_report_1 = SpecialReport->create(conn=>$conn, title => 'special report 1');
$author->articles->[2]->column( 'special_report_id' => $special_report_1->column('id') )->update;
$special_report_1->column( main_category_id => $category_4->column('id') )->update;


my $comment_id;
ok($comment_id = $author->articles->[0]->comments->[0]->column('id') );


# First simple test
my @authors = Author->find(conn=>$conn, with => [qw/articles articles.comments/]);
is(@authors, 1);
is($authors[0]->articles->[0]->column('title'), 'article title1');
is($authors[0]->articles->[1]->column('title'), 'article title2');
is( $authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment content first'
);


# Only data of deepest relationship should be loaded completely
@authors = Author->find(conn=>$conn, with => [qw/articles.comments/]);
is(@authors, 1);
ok( !defined $authors[0]->articles->[0]->column('title') );
ok( !defined $authors[0]->articles->[1]->column('title') );
is($authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment content first'
);


# Mixing the order of relationship chains a bit
@authors = Author->find(conn=>$conn, with => [qw/articles.comments articles/]);
is(@authors,                                                1);
is($authors[0]->articles->[0]->column('title'), 'article title1');
is($authors[0]->articles->[1]->column('title'), 'article title2');
is($authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment content first'
);


# Add another level to up the ante
SubComment->create(conn=>$conn, comment_id => $comment_id, content => 'sub comment 1');
SubComment->create(conn=>$conn, comment_id => $comment_id, content => 'sub comment 2');


###### Load all columns for each relationship
@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles articles.comments articles.comments.sub_comments/]);
is( @authors, 1);
is( @{$authors[0]->articles}, 4);
is( $authors[0]->articles->[0]->column('title'), 'article title1');
is( $authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment content first'
);
is( $authors[0]->articles->[0]->comments->[1]->column('content'),
    'comment content second'
);
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[0]
  ->column('content'), 'sub comment 1'
);
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[1]
  ->column('content'), 'sub comment 2'
);
is($authors[0]->articles->[2]->column('title'), 'article title3');
is( $authors[0]->articles->[2]->comments->[0]->column('content'),
    'comment content3'
);


###### Only data of deepest relationship should be loaded completely
@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.comments.sub_comments/]);
is( @authors, 1);
is( @{$authors[0]->articles}, 4);
ok( not defined $authors[0]->articles->[0]->column('title') );
is( @{$authors[0]->articles->[0]->comments}, 2);
ok( not defined $authors[0]->articles->[0]->comments->[0]->column('content') );
ok( not defined $authors[0]->articles->[0]->comments->[1]->column('content') );
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[0]
  ->column('content'),
    'sub comment 1'
);
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[1]
  ->column('content'),
    'sub comment 2'
);
ok( defined $authors[0]->articles->[1]->comments );
is( @{$authors[0]->articles->[1]->comments}, 0);


###### Follow a second path (articles.comments articles.main_category)
@authors = Author->find( conn=>$conn,
    with => [
        qw/articles articles.comments articles.comments.sub_comments articles.main_category/
    ]
);
is( @authors, 1);
is( @{$authors[0]->articles}, 4);
is( $authors[0]->articles->[0]->column('title'), 'article title1');
is( $authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment content first'
);
is( $authors[0]->articles->[0]->comments->[1]->column('content'),
    'comment content second'
);
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[0]
  ->column('content'), 'sub comment 1'
);
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[1]
  ->column('content'), 'sub comment 2'
);
is($authors[0]->articles->[2]->column('title'), 'article title3');
is( $authors[0]->articles->[2]->comments->[0]->column('content'),
    'comment content3'
);
is( $authors[0]->articles->[0]->main_category->column('title'), 'main category 4' );


@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.comments.sub_comments articles.main_category/]);
is( @authors, 1);
is( @{$authors[0]->articles}, 4);
ok( not defined $authors[0]->articles->[0]->column('title') );
is( @{$authors[0]->articles->[0]->comments}, 2);
ok( not defined $authors[0]->articles->[0]->comments->[0]->column('content') );
ok( not defined $authors[0]->articles->[0]->comments->[1]->column('content') );
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[0]
  ->column('content'),
    'sub comment 1'
);
is( $authors[0]->articles->[0]->comments->[0]->sub_comments->[1]
  ->column('content'),
    'sub comment 2'
);
is( @{$authors[0]->articles->[1]->comments}, 0);
is( $authors[0]->articles->[0]->main_category->column('title'), 'main category 4' );


@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.comments articles.main_category/]);
is( @authors, 1);
is( @{$authors[0]->articles}, 4);
ok( not defined $authors[0]->articles->[0]->column('title') );
is( @{$authors[0]->articles->[0]->comments}, 2);
is( $authors[0]->articles->[0]->comments->[0]->column('content'), 'comment content first');
is( $authors[0]->articles->[0]->comments->[1]->column('content'), 'comment content second');
is( @{$authors[0]->articles->[1]->comments}, 0);
is( $authors[0]->articles->[0]->main_category->column('title'), 'main category 4' );


@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.comments articles.main_category articles/]);
is( @authors, 1);
is( @{$authors[0]->articles}, 4);
is(  $authors[0]->articles->[0]->column('title'), 'article title1' );
is( @{$authors[0]->articles->[0]->comments}, 2);
is( $authors[0]->articles->[0]->comments->[0]->column('content'), 'comment content first');
is( $authors[0]->articles->[0]->comments->[1]->column('content'), 'comment content second');
is( @{$authors[0]->articles->[1]->comments}, 0);
is( $authors[0]->articles->[0]->main_category->column('title'), 'main category 4' );


###### One-to-many relationship follows a one-to-one relationship
my @articles =
  Article->find( conn=>$conn, 
    with => [qw/main_category.admin_histories/]);

is( $articles[0]->main_category->admin_histories->[0]->column('admin_name'), 'Andre1');
ok ( not defined $articles[0]->main_category->column('title') );


@articles =
  Article->find( conn=>$conn, 
    with => [qw/main_category main_category.admin_histories/]);


is( $articles[0]->main_category->admin_histories->[0]->column('admin_name'), 'Andre1');
is ( $articles[0]->main_category->column('title'), 'main category 4' );


@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.main_category.admin_histories/]);

is( $authors[0]->articles->[0]->main_category->admin_histories->[0]->column('admin_name'), 'Andre1');
ok ( not defined $authors[0]->articles->[0]->main_category->column('title') );



###### One-to-many relationship follows TWO one-to-one/many-to-one relationships
@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.special_report.main_category.admin_histories/]);

is( $authors[0]->articles->[2]->special_report->main_category->admin_histories->[0]->column('admin_name'), 'Andre1');
ok ( not defined $authors[0]->articles->[2]->special_report->main_category->column('title') );


@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.special_report.main_category articles.special_report.main_category.admin_histories/]);

is( $authors[0]->articles->[2]->special_report->main_category->admin_histories->[0]->column('admin_name'), 'Andre1');
is( $authors[0]->articles->[2]->special_report->main_category->column('title'), 'main category 4' );


@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.special_report.main_category articles.special_report.main_category.admin_histories/]);

is( $authors[0]->articles->[2]->special_report->main_category->admin_histories->[0]->column('admin_name'), 'Andre1');
is( $authors[0]->articles->[2]->special_report->main_category->column('title'), 'main category 4' );


@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.comments articles.special_report.main_category.admin_histories/]);
is( $authors[0]->articles->[2]->special_report->main_category->admin_histories->[0]->column('admin_name'), 'Andre1');
ok( not defined $authors[0]->articles->[2]->special_report->main_category->column('title') );
ok( not defined $authors[0]->articles->[2]->column('title') );
is( $authors[0]->articles->[2]->comments->[0]->column('content'), 'comment content3' );


# Pass specific article id
my $article =
  Article->find( conn=>$conn, id=>$author->articles->[2]->column('id'),
    with => [qw/special_report.main_category.admin_histories/]);
is( $article->special_report->main_category->admin_histories->[0]->column('admin_name'), 'Andre1');
ok ( not defined $article->special_report->main_category->column('title') );


# Pass specific article id, make sure that later subrequest is performed even
# if first subrequest does not provide any results
$article =
  Article->find( conn=>$conn, id=>$author->articles->[3]->column('id'),
    with => [qw/to_do_articles special_report.main_category.admin_histories/]);
is( $article->to_do_articles->[0]->column('to_do'), 'to do 4');

# related object should not exist if no data exists for this object (empty objects not allowed)
ok( not defined $article->special_report );



######################################################################
###### Using columns that do not follow naming conventions
###### Using columns for mapping that are not primary key columns
###### Map different tables using multiple columns

# Create data and test
my $hotel = Hotel->create(
    conn      => $conn,
    name      => 'President',
    hotel_num_a => 5,
    apartments => [
        {   apartment_num_b => 47,
            name          => 'John F. Kennedy',
            size          => 78,
            rooms => [
                {room_num_c => 1, size => 70},
                {room_num_c => 2, size => 8}
            ]
        },
        {   apartment_num_b => 61,
            name          => 'George Washington',
            size          => 50,
            rooms => [
                {room_num_c => 1, size => 10},
                {room_num_c => 2, size => 15},
                {room_num_c => 3, size => 25}
            ]
        },
    ],
    manager => 
        {   manager_num_b => 5555555,
            name          => 'Lalolu',
            telefon_numbers => [
                {tel_num_c => 1111, telefon_number => '123456789'},
                {tel_num_c => 1112, telefon_number => '987654321'}
            ]
        }
);

# Just to be sure: test the data that has just been created
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
is( $hotel->apartments->[1]->rooms->[1]->column('size'), 15);
is( $hotel->apartments->[1]->rooms->[2]->column('room_num_c'), 3);
is( $hotel->apartments->[1]->rooms->[2]->column('size'), 25);

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


# Create a second hotel with same data (except hotel_num, hotel name and manager_num)
# to make tests a bit more demanding
# important to make sure that object mapping not only works accidentally
my $hotel2 = Hotel->create(
    conn      => $conn,
    name      => 'President2',
    hotel_num_a => 6,
    apartments => [
        {   apartment_num_b => 47,
            name          => 'John F. Kennedy',
            size          => 78,
            rooms => [
                {room_num_c => 1, size => 70},
                {room_num_c => 2, size => 8}
            ]
        },
        {   apartment_num_b => 61,
            name          => 'George Washington',
            size          => 50,
            rooms => [
                {room_num_c => 1, size => 10},
                {room_num_c => 2, size => 15},
                {room_num_c => 3, size => 25}
            ]
        },
    ],
    manager => 
        {   manager_num_b => 666666,
            name          => 'Lalolu',
            telefon_numbers => [
                {tel_num_c => 1111, telefon_number => '123456789'},
                {tel_num_c => 1112, telefon_number => '987654321'}
            ]
        }
);



# Now get comparable object via find

my @hotels =
  Hotel->find( conn=>$conn,
    with => [qw/apartments apartments.rooms/]);

is( @{$hotels[0]->apartments}, 2 );
is( $hotels[0]->apartments->[0]->column('apartment_num_b'), 47 );
is( $hotels[0]->apartments->[0]->column('name'), 'John F. Kennedy' );
is( $hotels[0]->apartments->[0]->column('size'), 78 );

is( $hotels[0]->apartments->[1]->column('apartment_num_b'), 61 );
is( $hotels[0]->apartments->[1]->column('name'), 'George Washington' );
is( $hotels[0]->apartments->[1]->column('size'), 50 );

is( @{$hotels[0]->apartments->[0]->rooms}, 2 );
is( $hotels[0]->apartments->[0]->rooms->[0]->column('room_num_c'), 1);
is( $hotels[0]->apartments->[0]->rooms->[0]->column('size'), 70);
is( $hotels[0]->apartments->[0]->rooms->[1]->column('room_num_c'), 2);
is( $hotels[0]->apartments->[0]->rooms->[1]->column('size'), 8);

is( @{$hotels[0]->apartments->[1]->rooms}, 3 );
is( $hotels[0]->apartments->[1]->rooms->[0]->column('room_num_c'), 1);
is( $hotels[0]->apartments->[1]->rooms->[0]->column('size'), 10);
is( $hotels[0]->apartments->[1]->rooms->[1]->column('room_num_c'), 2);
is( $hotels[0]->apartments->[1]->rooms->[1]->column('size'), 15);
is( $hotels[0]->apartments->[1]->rooms->[2]->column('room_num_c'), 3);
is( $hotels[0]->apartments->[1]->rooms->[2]->column('size'), 25);


is( $hotels[0]->apartments->[0]->column('hotel_num_b'), 5 );
is( $hotels[0]->apartments->[1]->column('hotel_num_b'), 5 );

is( $hotels[0]->apartments->[0]->rooms->[0]->column('hotel_num_c'), 5);
is( $hotels[0]->apartments->[0]->rooms->[1]->column('hotel_num_c'), 5);
is( $hotels[0]->apartments->[0]->rooms->[0]->column('apartment_num_c'), 47);
is( $hotels[0]->apartments->[0]->rooms->[1]->column('apartment_num_c'), 47);

is( $hotels[0]->apartments->[1]->rooms->[0]->column('hotel_num_c'), 5);
is( $hotels[0]->apartments->[1]->rooms->[1]->column('hotel_num_c'), 5);
is( $hotels[0]->apartments->[1]->rooms->[2]->column('hotel_num_c'), 5);
is( $hotels[0]->apartments->[1]->rooms->[0]->column('apartment_num_c'), 61);
is( $hotels[0]->apartments->[1]->rooms->[1]->column('apartment_num_c'), 61);
is( $hotels[0]->apartments->[1]->rooms->[2]->column('apartment_num_c'), 61);


# one-to-many rel follows one-to-one rel
@hotels =
  Hotel->find( conn=>$conn,
    with => [qw/manager manager.telefon_numbers/]);

is( $hotels[0]->manager->column('name'), 'Lalolu' );
is( $hotels[0]->manager->column('hotel_num_b'), 5 );

is( @{$hotels[0]->manager->telefon_numbers}, 2);
is( $hotels[0]->manager->telefon_numbers->[0]->column('telefon_number'), '123456789' );
is( $hotels[0]->manager->telefon_numbers->[1]->column('telefon_number'), '987654321' );
is( $hotels[0]->manager->telefon_numbers->[0]->column('manager_num_c'), '5555555' );
is( $hotels[0]->manager->telefon_numbers->[1]->column('manager_num_c'), '5555555' );


# Make sure that columns for mapping are present even if no columns should be loaded
@hotels =
  Hotel->find( conn=>$conn, columns=>[],
    with => [qw/apartments apartments.rooms/]);
is( @{$hotels[0]->apartments}, 2 );
is( @{$hotels[0]->apartments->[0]->rooms}, 2 );


# Make sure that columns for mapping are present even if not all apartment columns are loaded
@hotels =
  Hotel->find( conn=>$conn,
    with => [qw/apartments.rooms/]);
is( @{$hotels[0]->apartments}, 2 );
is( @{$hotels[0]->apartments->[0]->rooms}, 2 );

### FAILING TEST: Putting the same table in different parts of the object hierarchy
#@articles =
#  Article->find( conn=>$conn, 
#    with => [qw/main_category special_report.main_category.admin_histories/]);
#is( $articles[2]->special_report->main_category->admin_histories->[0]->column('admin_name'), 'Andre1');





# Cleanup
Author->delete(conn => $conn);
MainCategory->delete(conn => $conn);


