#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 20;

use_ok(
    'ObjectDB::Utils',  'camelize',
    'decamelize',       'single_to_plural',
    'plural_to_single', 'class_to_table',
    'table_to_class'
);

is(camelize('hello'),            'Hello');
is(camelize('hello_there'),      'HelloThere');
is(camelize('hello_there-here'), 'HelloThere::Here');
is(camelize('a_b_c'),            'ABC');

is(decamelize('Hello'),            'hello');
is(decamelize('HelloThere'),       'hello_there');
is(decamelize('HelloThere::Here'), 'hello_there-here');
is(decamelize('ABC'),              'a_b_c');

is(single_to_plural('article'),  'articles');
is(single_to_plural('key'),      'keys');
is(single_to_plural('category'), 'categories');

is(plural_to_single('articles'),   'article');
is(plural_to_single('keys'),       'key');
is(plural_to_single('categories'), 'category');

is(class_to_table('Article'),  'articles');
is(table_to_class('articles'), 'Article');

is(class_to_table('CategoryHistory'),    'category_histories');
is(decamelize('CategoryHistory'),        'category_history');
is(single_to_plural('category_history'), 'category_histories');
