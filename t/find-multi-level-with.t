#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 68;

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
        }
    ]
);

my $category_1 = MainCategory->create(conn=>$conn, title => 'main category 1');
my $category_2 = MainCategory->create(conn=>$conn, title => 'main category 2');
$author->articles->[0]->column( 'main_category_id' => $category_1->column('id') )->update;


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

# Same tests with autoload of articles
@authors = Author->find(conn=>$conn, with => [qw/articles.comments/]);
is(@authors, 1);
ok( !defined $authors[0]->articles->[0]->column('title') );
ok( !defined $authors[0]->articles->[1]->column('title') );
is($authors[0]->articles->[0]->comments->[0]->column('content'),
    'comment content first'
);

# Make sure that articles do not load a second time
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


# Find all authors with all articles with all comments with podcast
@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles articles.comments articles.comments.sub_comments/]);
is( @authors, 1);
is( @{$authors[0]->articles}, 3);
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


# Find all authors with all articles with all comments with all subcomments
@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.comments.sub_comments/]);
is( @authors, 1);
is( @{$authors[0]->articles}, 3);
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


@authors = Author->find( conn=>$conn,
    with => [
        qw/articles articles.comments articles.comments.sub_comments articles.main_category/
    ]
);
is( @authors, 1);
is( @{$authors[0]->articles}, 3);
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
is( $authors[0]->articles->[0]->main_category->column('title'), 'main category 1' );


# Find all authors with all articles with all comments with all subcomments
@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.comments.sub_comments articles.main_category/]);
is( @authors, 1);
is( @{$authors[0]->articles}, 3);
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
is( $authors[0]->articles->[0]->main_category->column('title'), 'main category 1' );


# Find all authors with all articles with all comments with all subcomments
@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.comments articles.main_category/]);
is( @authors, 1);
is( @{$authors[0]->articles}, 3);
ok( not defined $authors[0]->articles->[0]->column('title') );
is( @{$authors[0]->articles->[0]->comments}, 2);
is( $authors[0]->articles->[0]->comments->[0]->column('content'), 'comment content first');
is( $authors[0]->articles->[0]->comments->[1]->column('content'), 'comment content second');
is( @{$authors[0]->articles->[1]->comments}, 0);
is( $authors[0]->articles->[0]->main_category->column('title'), 'main category 1' );



# 
@authors =
  Author->find( conn=>$conn, 
    with => [qw/articles.comments articles.main_category articles/]);
is( @authors, 1);
is( @{$authors[0]->articles}, 3);
is(  $authors[0]->articles->[0]->column('title'), 'article title1' );
is( @{$authors[0]->articles->[0]->comments}, 2);
is( $authors[0]->articles->[0]->comments->[0]->column('content'), 'comment content first');
is( $authors[0]->articles->[0]->comments->[1]->column('content'), 'comment content second');
is( @{$authors[0]->articles->[1]->comments}, 0);
is( $authors[0]->articles->[0]->main_category->column('title'), 'main category 1' );




# Cleanup
Author->delete(conn => $conn);
MainCategory->delete(conn => $conn);


