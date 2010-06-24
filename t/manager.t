#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;

use lib 't/lib';

use TestDB;

use ObjectDB::Manager;

my $conn = TestDB->conn;

my $manager = ObjectDB::Manager->new(conn => $conn);

my $author = $manager->create(author => name => 'foo');
ok($author);

$author = $manager->find(author => id => $author->id);
ok($author);

$author->delete;
