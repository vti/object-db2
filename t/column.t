#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;

use lib 't/lib';

use TestEnv;
use Author;

TestEnv->setup;

my $author = Author->new;

ok($author);

ok(not defined $author->column(undef));
ok(not defined $author->id);

$author->id('boo');
is($author->id, 'boo');

$author->id(undef);
ok(not defined $author->id);

$author->id('bar');
is($author->id, 'bar');

TestEnv->teardown;
