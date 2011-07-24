#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;

use lib 't/lib';

use Author;

my $author = Author->new;

ok($author);

ok(not defined $author->column(undef));
ok(not defined $author->column('id'));

$author->column(id => 'boo');
is($author->column('id'), 'boo');

$author->column(id => undef);
ok(not defined $author->column('id'));

$author->column(id => 'bar');
is($author->column('id'), 'bar');
