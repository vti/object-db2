#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;

use ObjectDB;

is_deeply(ObjectDB->_normalize_with([qw/foo/]), [{name => 'foo'}]);
is_deeply(ObjectDB->_normalize_with([foo => {a => 'b'}]),
    [{name => 'foo', a => 'b'}]);
is_deeply(
    ObjectDB->_normalize_with([qw/foo foo.bar/]),
    [{name => 'foo'}, {name => 'foo.bar'}]
);
is_deeply(
    ObjectDB->_normalize_with([qw/foo.bar/]),
    [{name => 'foo'}, {name => 'foo.bar'}]
);
is_deeply(
    ObjectDB->_normalize_with([qw/hello foo.bar/]),
    [{name => 'foo'}, {name => 'foo.bar'}, {name => 'hello'}]
);
is_deeply(
    ObjectDB->_normalize_with([hello => {a => 'b'}, qw/foo.bar.baz/]),
    [   {name => 'foo'},
        {name => 'foo.bar'},
        {name => 'foo.bar.baz'},
        {name => 'hello', a => 'b'}
    ]
);
