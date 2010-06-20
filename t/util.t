#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 17;

use_ok('ObjectDB::Util');

is(ObjectDB::Util->camelize('hello'), 'Hello');
is(ObjectDB::Util->camelize('hello_there'), 'HelloThere');
is(ObjectDB::Util->camelize('hello_there-here'), 'HelloThere::Here');
is(ObjectDB::Util->camelize('a_b_c'), 'ABC');

is(ObjectDB::Util->decamelize('Hello'), 'hello');
is(ObjectDB::Util->decamelize('HelloThere'), 'hello_there');
is(ObjectDB::Util->decamelize('HelloThere::Here'), 'hello_there-here');
is(ObjectDB::Util->decamelize('ABC'), 'a_b_c');

is(ObjectDB::Util->single_to_plural('article'), 'articles');
is(ObjectDB::Util->single_to_plural('key'), 'keys');
is(ObjectDB::Util->single_to_plural('category'), 'categories');

is(ObjectDB::Util->plural_to_single('articles'), 'article');
is(ObjectDB::Util->plural_to_single('keys'), 'key');
is(ObjectDB::Util->plural_to_single('categories'), 'category');

is(ObjectDB::Util->class_to_table('Article'), 'articles');
is(ObjectDB::Util->table_to_class('articles'), 'Article');
