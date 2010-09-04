#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 7;

use_ok('ObjectDB::SQL::Utils', 'escape', 'prepare_column');

is(escape('foo'),  '`foo`');
is(escape('fo`o'), '`fo\`o`');

is(prepare_column('foo'),     '`foo`');
is(prepare_column('foo.bar'), '`foo`.`bar`');
is(prepare_column('foo.bar', 'baz'), '`foo`.`bar`');
is(prepare_column('bar',     'baz'), '`baz`.`bar`');
