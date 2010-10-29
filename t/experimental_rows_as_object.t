#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 12;

use lib 't/lib';

use TestEnv;
use Schema::AuthorData;

TestEnv->setup;

Schema::AuthorData->populate;


# Classic iterator
my $authors = Schema::Author->find(with => ['articles.comments'],);


# Now with rows_as_object option (for highest level) and
# sub rows_as_objects {1} for related objects
$authors = Schema::Author->find(
    with => ['articles.comments'],
);

# row(0) instead of ->[0]
is($authors->row(0)->articles->row(0)->comments->row(0)->column('content'),
    'comment 1-1-1');


# ->number of rows
is($authors->row(0)->articles->row(0)->comments->number_of_rows, 6);


# ->next
for (
    my $i = 1;
    $i <= $authors->row(0)->articles->row(0)->comments->number_of_rows;
    $i++
  )
{
    is($authors->row(0)->articles->row(0)->comments->next->column('content'),
        'comment 1-1-' . $i);
}
is($authors->row(0)->articles->row(0)->comments->next, undef);


# Different way to loop
my @test;
while (my $row = $authors->row(0)->articles->row(0)->comments->next) {
    push @test, $row->column('content');
}
is_deeply(
    \@test,
    [   'comment 1-1-1',
        'comment 1-1-2',
        'comment 1-1-3',
        'comment 1-1-4',
        'comment 1-1-5',
        'comment 1-1-6'
    ]
);


# Rows are not deleted by next in prefetch mode
is($authors->row(0)->articles->row(0)->comments->number_of_rows, 6);


# to_hash
my $authors_serialized = $authors->to_hash;
is($authors_serialized->[0]->{articles}->[0]->{comments}->[0]->{content}, 'comment 1-1-1');



Schema::AuthorData->cleanup;


TestEnv->teardown;
