#!/usr/bin/env perl

package Foo;
use base 'ObjectDB';
__PACKAGE__->schema('foo');


package Foo::Deeper;
use base 'ObjectDB';
__PACKAGE__->schema;


package main;

use strict;
use warnings;

use Test::More tests => 9;

use_ok('ObjectDB::Relationship::Base');

my $rel = ObjectDB::Relationship::Base->new(
    class => 'Foo',
    name  => 'foo'
);
ok($rel);

is($rel->type,  'base');
is($rel->name,  'foo');
is($rel->class, 'Foo');


# No table name passed, table name derived from class
$rel = ObjectDB::Relationship::Base->new(
    class => 'Foo::Deeper',
    name  => 'test_no_table'
);
ok($rel);

is($rel->name,  'test_no_table');
is($rel->class, 'Foo::Deeper');
is($rel->table, 'deepers');
