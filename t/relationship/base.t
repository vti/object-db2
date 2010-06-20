#!/usr/bin/env perl

package Foo;
use base 'ObjectDB';
__PACKAGE__->schema('foo');

package main;

use strict;
use warnings;

use Test::More tests => 5;

use_ok('ObjectDB::Relationship::Base');

my $rel = ObjectDB::Relationship::Base->new(
    class => 'Foo',
    name  => 'foo'
);
ok($rel);

is($rel->type,  'base');
is($rel->name,  'foo');
is($rel->class, 'Foo');
