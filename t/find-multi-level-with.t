#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 274;

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


######################################################################
###### 1. following naming conventions

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



######################################################################
###### 1.1 One-to-Many --> One-to-Many (--> One-to-Many)

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



######################################################################
###### 1.2 Mix One-to-Many x 3 (up to 3 levels) AND One-to-Many --> One-to-One
###### articles.comments articles.main_category)

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



######################################################################
###### 1.3 One-to-One --> One-to-Many
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



######################################################################
###### 1.3 TWO one-to-one/many-to-one --> One-to-many

@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.special_report.main_category.admin_histories/]);
is( $authors[0]->articles->[2]->special_report->main_category->admin_histories->[0]->column('admin_name'), 'Andre1');
ok( not defined $authors[0]->articles->[2]->special_report->main_category->column('title') );



@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.special_report.main_category articles.special_report.main_category.admin_histories/]);
is( $authors[0]->articles->[2]->special_report->main_category->admin_histories->[0]->column('admin_name'), 'Andre1');
is( $authors[0]->articles->[2]->special_report->main_category->column('title'), 'main category 4' );



### mix
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
###### 2. crazy naming
###### Using columns for mapping that do not follow naming conventions
###### Using columns for mapping that are not primary key columns
###### Map tables using multiple columns

# Create data
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
                {room_num_c => 2, size => 16},
                {room_num_c => 3, size => 70}
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
                {room_num_c => 1, size => 10, maid=>{name=>'Amelie'}},
                {room_num_c => 2, size => 15, maid=>{name=>'Lucy'}},
                {room_num_c => 3, size => 25, maid=>{name=>'Sissy'}}
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


# Create a third hotel
my $hotel3 = Hotel->create(
    conn      => $conn,
    name      => 'President3',
    hotel_num_a => 7,
    apartments => [
        {   apartment_num_b => 11,
            name          => 'John F. Kennedy',
            size          => 78,
            rooms => [
                {room_num_c => 1, size => 71},
                {room_num_c => 2, size => 7}
            ]
        },
        {   apartment_num_b => 12,
            name          => 'George Washington',
            size          => 50,
            rooms => [
                {room_num_c => 1, size => 9},
                {room_num_c => 2, size => 15},
                {room_num_c => 3, size => 25},
                {room_num_c => 4, size => 7},
                {room_num_c => 5, size => 7}
            ]
        },
    ],
    manager => 
        {   manager_num_b => 777777,
            name          => 'Smith',
            telefon_numbers => [
                {tel_num_c => 3111, telefon_number => '12121212'},
                {tel_num_c => 3222, telefon_number => '33445566'}
            ]
        }
);




######################################################################
###### 2.1 One-to-Many -> One-to-Many

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
is( $hotels[0]->apartments->[1]->rooms->[1]->column('size'), 16);
is( $hotels[0]->apartments->[1]->rooms->[2]->column('room_num_c'), 3);
is( $hotels[0]->apartments->[1]->rooms->[2]->column('size'), 70);


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



# Make sure that columns for mapping are present even if no columns should be loaded
@hotels =
  Hotel->find( conn=>$conn, columns=>[],
    with => [qw/apartments apartments.rooms/]);
is( $hotels[0]->column('hotel_num_a'), 5 );
ok( $hotels[0]->column('id') );
ok( not defined $hotels[0]->column('name') );
is( @{$hotels[0]->apartments}, 2 );
is( @{$hotels[0]->apartments->[0]->rooms}, 2 );



# one-to-one after one-to-many to make sure that column aliases work correctly in find_related
# map: rooms.apartment_num_c => maid.apartment_num_c, i.e. same column name for mapping in both tables
@hotels =
  Hotel->find( conn=>$conn,
    with => [qw/apartments apartments.rooms.maid/]);
is( $hotels[1]->apartments->[1]->rooms->[0]->maid->column('name'), 'Amelie' );



# Make sure that columns for mapping are present even if not all apartment columns are loaded
@hotels =
  Hotel->find( conn=>$conn,
    with => [qw/apartments.rooms/]);
ok( $hotels[0]->apartments->[0]->column('id') );
is( $hotels[0]->apartments->[0]->column('hotel_num_b'), 5 );
is( $hotels[0]->apartments->[0]->column('apartment_num_b'), 47 );
ok( not defined $hotels[0]->apartments->[0]->column('name') );
is( @{$hotels[0]->apartments}, 2 );
is( @{$hotels[0]->apartments->[0]->rooms}, 2 );
is( $hotels[0]->apartments->[0]->rooms->[0]->column('size'), 70);

my $hotel_id = $hotels[0]->column('id');



# Same test with specific id
$hotel =
  Hotel->find( conn=>$conn, id=>$hotel_id,
    with => [qw/apartments.rooms/]);
ok( $hotel->apartments->[0]->column('id') );
is( $hotel->apartments->[0]->column('hotel_num_b'), 5 );
is( $hotel->apartments->[0]->column('apartment_num_b'), 47 );
ok( not defined $hotel->apartments->[0]->column('name') );
is( @{$hotel->apartments}, 2 );
is( @{$hotel->apartments->[0]->rooms}, 2 );
is( $hotel->apartments->[0]->rooms->[0]->column('size'), 70);



######################################################################
#### 2.2 One-to-One --> One-to-Many 

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

$hotel_id = $hotels[0]->column('id');



# same test with passed id
$hotel =
  Hotel->find( conn=>$conn, id=>$hotel_id,
    with => [qw/manager manager.telefon_numbers/] );
is( $hotel->manager->column('name'), 'Lalolu' );
is( $hotel->manager->column('hotel_num_b'), 5 );
is( @{$hotel->manager->telefon_numbers}, 2);
is( $hotel->manager->telefon_numbers->[0]->column('telefon_number'), '123456789' );
is( $hotel->manager->telefon_numbers->[1]->column('telefon_number'), '987654321' );
is( $hotel->manager->telefon_numbers->[0]->column('manager_num_c'), '5555555' );
is( $hotel->manager->telefon_numbers->[1]->column('manager_num_c'), '5555555' );



# same test, but do not load manager data
@hotels =
  Hotel->find( conn=>$conn,
    with => [qw/manager.telefon_numbers/]);
ok( not defined $hotels[0]->manager->column('name') );
ok( $hotels[0]->manager->column('id') );
is( $hotels[0]->manager->column('hotel_num_b'), 5 );
is( $hotels[0]->manager->column('manager_num_b'), 5555555 );
is( @{$hotels[0]->manager->telefon_numbers}, 2);
is( $hotels[0]->manager->telefon_numbers->[0]->column('telefon_number'), '123456789' );
is( $hotels[0]->manager->telefon_numbers->[1]->column('telefon_number'), '987654321' );
is( $hotels[0]->manager->telefon_numbers->[0]->column('manager_num_c'), '5555555' );
is( $hotels[0]->manager->telefon_numbers->[1]->column('manager_num_c'), '5555555' );



######################################################################
#### 2.3 Mix 2.1 and 2.2
@hotels =
  Hotel->find( conn=>$conn,
    with => [qw/manager.telefon_numbers apartments.rooms/]);
is( @{$hotels[0]->apartments}, 2 );
ok( not defined $hotels[0]->apartments->[0]->column('name') );
ok( not defined $hotels[0]->manager->column('name') );
is( $hotels[0]->manager->telefon_numbers->[0]->column('telefon_number'), '123456789' );
is( $hotels[0]->apartments->[1]->rooms->[2]->column('size'), 70);



######################################################################
#### 2.4. include "where" parameter in "with" to only prefetch data that
#### meets certain criteria

# has_many relationship
@hotels =
  Hotel->find( conn=>$conn,
    with => [ 'apartments.rooms' => { where=>[ size=>70 ] }, 'apartments' ] );
is( @hotels, 3);
is( @{$hotels[0]->apartments}, 2 );
is( @{$hotels[1]->apartments}, 2 );
is( @{$hotels[2]->apartments}, 2 );
is( @{$hotels[0]->apartments->[0]->rooms}, 1 );
is( @{$hotels[0]->apartments->[1]->rooms}, 1 );
is( @{$hotels[1]->apartments->[0]->rooms}, 1 );
is( @{$hotels[1]->apartments->[1]->rooms}, 0 );
is( @{$hotels[2]->apartments->[0]->rooms}, 0 );
is( @{$hotels[2]->apartments->[1]->rooms}, 0 );



# has_many relationship
@hotels =
  Hotel->find( conn=>$conn,
    with => [ 'apartments.rooms' => { where=>[ size=>70 ] }, 'apartments' => { where=>[ name=>'John F. Kennedy' ] } ] );
is( @hotels, 3);
is( @{$hotels[0]->apartments}, 1 );
is( @{$hotels[1]->apartments}, 1 );
is( @{$hotels[2]->apartments}, 1 );
is( @{$hotels[0]->apartments->[0]->rooms}, 1 );
is( @{$hotels[1]->apartments->[0]->rooms}, 1 );
is( @{$hotels[2]->apartments->[0]->rooms}, 0 );


# multi-level where
@hotels =
  Hotel->find( conn=>$conn,
    with => [ 'apartments' => { where=>[ 'rooms.size'=>15 ] } ] );
is( @hotels, 3);
is( @{$hotels[0]->apartments}, 0 );
is( @{$hotels[1]->apartments}, 1 );
is( $hotels[1]->apartments->[0]->column('apartment_num_b'), 61 );
is( @{$hotels[2]->apartments}, 1 );
is( $hotels[2]->apartments->[0]->column('apartment_num_b'), 12 );


@hotels =
  Hotel->find( conn=>$conn,
    with => [ 'apartments' => { where=>[ 'rooms.size'=>7 ] } ] );
is( @hotels, 3);
is( @{$hotels[0]->apartments}, 0 );
is( @{$hotels[1]->apartments}, 0 );
is( @{$hotels[2]->apartments}, 2 );
is( $hotels[2]->apartments->[0]->column('apartment_num_b'), 11 );
is( $hotels[2]->apartments->[1]->column('apartment_num_b'), 12 );


# has_one relationship
@hotels =
  Hotel->find( conn=>$conn,
    with => [ 'manager' => { where=>[ name=>'Lalolu' ] } ] );
is( @hotels, 3);
is( $hotels[0]->manager->column('name'), 'Lalolu' );
is( $hotels[1]->manager->column('name'), 'Lalolu' );
is( $hotels[2]->manager, undef );




######################################################################
#### 3. NO prefetch

# telefon_numbers are NOT prefetched, array ref should be returned
@hotels =
  Hotel->find( conn=>$conn,
    with => [qw/manager/]);
is( $hotels[0]->manager->telefon_numbers->[0]->column('telefon_number'), '123456789' );



# manager is not prefetched, a manager object should be returned
@hotels =
  Hotel->find( conn=>$conn );
is( $hotels[0]->manager->column('name'), 'Lalolu' );



######################################################################
#### 4. where and multi-level-with

# No match at all
@hotels =
  Hotel->find( conn=>$conn,
    with => [qw/manager manager.telefon_numbers apartments apartments.rooms/],
    where => [ 'manager.name'=>'Smith2' ] );
is( @hotels, 0);



# One match
@hotels =
  Hotel->find( conn=>$conn,
    with => [qw/manager manager.telefon_numbers apartments apartments.rooms/],
    where => [ 'manager.name'=>'Smith' ] );
is( @hotels, 1);
is( $hotels[0]->manager->column('name'), 'Smith' );
is( $hotels[0]->manager->telefon_numbers->[0]->column('telefon_number'), '12121212' );
is( @{$hotels[0]->apartments}, 2 );
is( $hotels[0]->apartments->[0]->column('name'), 'John F. Kennedy' );
is( $hotels[0]->apartments->[0]->rooms->[0]->column('size'), 71 );



# One matching hotel, "with" dominates "where" (so all apartments
# with all rooms are loaded for the matching hotel (where
# condition does not apply to subrequests for apartments and rooms)
@hotels =
  Hotel->find( conn=>$conn,
    with => [qw/manager manager.telefon_numbers apartments apartments.rooms/],
    where => [ 'apartments.rooms.size'=> 71 ] );
is( @hotels, 1);
is( $hotels[0]->manager->column('name'), 'Smith' );
is( $hotels[0]->manager->telefon_numbers->[0]->column('telefon_number'), '12121212' );
is( @{$hotels[0]->apartments}, 2 );
is( $hotels[0]->apartments->[0]->column('name'), 'John F. Kennedy' );
is( @{$hotels[0]->apartments->[0]->rooms}, 2);
is( $hotels[0]->apartments->[0]->rooms->[0]->column('size'), 71 );



# Similar test, but now two matching hotels
@hotels =
  Hotel->find( conn=>$conn,
    with => [qw/manager manager.telefon_numbers apartments apartments.rooms/],
    where => [ 'apartments.rooms.size'=> 10 ] );
is( @hotels, 2);
is( $hotels[0]->column('hotel_num_a'), 5 );
is( $hotels[1]->column('hotel_num_a'), 6 );
is( $hotels[0]->manager->column('name'), 'Lalolu' );
is( $hotels[0]->manager->telefon_numbers->[1]->column('telefon_number'), '987654321' );
is( @{$hotels[0]->apartments}, 2 );
is( $hotels[0]->apartments->[0]->column('name'), 'John F. Kennedy' );
is( @{$hotels[0]->apartments->[0]->rooms}, 2);
is( $hotels[0]->apartments->[0]->rooms->[0]->column('size'), 70 );



# Similar test, but now LOOKING FOR ROOMS WITH SAME SIZE IN ONE HOTEL
@hotels =
  Hotel->find( conn=>$conn,
    with => [qw/manager manager.telefon_numbers apartments apartments.rooms/],
    where => [ 'apartments.rooms.size'=> 70 ] );
is( @hotels, 2); ### should still be 2, not 3 as in sql (left join)
is( $hotels[0]->column('hotel_num_a'), 5 );
is( $hotels[1]->column('hotel_num_a'), 6 );
is( @{$hotels[0]->apartments}, 2 );
is( @{$hotels[1]->apartments}, 2 );
is( @{$hotels[0]->apartments->[0]->rooms}, 2 );
is( @{$hotels[0]->apartments->[1]->rooms}, 3 );
is( @{$hotels[1]->apartments->[0]->rooms}, 2 );
is( @{$hotels[1]->apartments->[1]->rooms}, 3 );



# Similar test, but now WITHOUT WITH
@hotels =
  Hotel->find( conn=>$conn,
    where => [ 'apartments.rooms.size'=> 70 ] );
is( @hotels, 2); ### should still be 2, not 3 as in sql (left join)
is( $hotels[0]->column('hotel_num_a'), 5 );
is( $hotels[1]->column('hotel_num_a'), 6 );

# TO DO: check in tests whether data has been prefetched (or loaded afterwards)
# TO DO: create more complex where related tests in seperate file
# is( @{$hotels[0]->apartments}, undef );



# one-to-one relationships with multiple column mapping
my @rooms =
  Room->find( conn=>$conn,
    with => [qw/ apartment apartment.hotel /] );
is( @rooms, 17);
is( $rooms[0]->column('size'), 70 );
is( $rooms[0]->apartment->hotel->column('name'), 'President' );
is( $rooms[7]->column('size'), 10 );
is( $rooms[7]->apartment->hotel->column('name'), 'President2' );


# Similar test with "where" condition
@rooms =
  Room->find( conn=>$conn,
    with => [qw/ apartment apartment.hotel /],
    where => [ 'apartment.hotel.name' => 'President' ] );
is( @rooms, 5);
is( $rooms[3]->column('size'), 16 );
is( $rooms[3]->apartment->hotel->column('name'), 'President' );


######################################################################
### FAILING TEST: Putting the same table in different parts of the object hierarchy
#@articles =
#  Article->find( conn=>$conn, 
#    with => [qw/main_category special_report.main_category.admin_histories/]);
#is( $articles[2]->special_report->main_category->admin_histories->[0]->column('admin_name'), 'Andre1');





# Cleanup
Author->delete(conn => $conn);
MainCategory->delete(conn => $conn);
Hotel->delete(conn => $conn);
