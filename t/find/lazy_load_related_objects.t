#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;

use lib 't/lib';


use TestEnv;
TestEnv->setup;


use HotelData;
HotelData->populate;


# telefon_numbers are NOT prefetched, array ref should be returned
my @hotels = Hotel->new->find(with => [qw/manager/]);
is($hotels[0]->manager->telefon_numbers->[0]->column('telefon_number'),
    '123456789');


# manager is not prefetched, a manager object should be returned
@hotels = Hotel->new->find;
is($hotels[0]->manager->column('name'), 'Lalolu');


HotelData->cleanup;

TestEnv->teardown;
