#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 5;

use ObjectDB;

is_deeply(ObjectDB->_fix_with([qw/foo/]), [qw/foo/]);
is_deeply(ObjectDB->_fix_with([qw/foo foo.bar/]), [qw/foo foo.bar/]);
is_deeply(ObjectDB->_fix_with([qw/foo.bar/]), [qw/foo foo.bar/]);
is_deeply(ObjectDB->_fix_with([qw/hello foo.bar/]), [qw/foo foo.bar hello/]);
is_deeply(ObjectDB->_fix_with([qw/hello foo.bar.baz/]), [qw/foo foo.bar foo.bar.baz hello/]);
