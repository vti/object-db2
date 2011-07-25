#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 7;

use ObjectDB::Finder;

is_deeply(ObjectDB::Finder->_normalize_with([qw/foo/]), [foo => {}]);
is_deeply(ObjectDB::Finder->_normalize_with([foo => {a => 'b'}]),
    [foo => {a => 'b'}]);
is_deeply(ObjectDB::Finder->_normalize_with([qw/foo foo.bar/]),
    [foo => {nested => [bar => {}]}]);
is_deeply(
    ObjectDB::Finder->_normalize_with([qw/foo.bar/]),
    [foo => {columns => [], nested => [bar => {}]}]
);
is_deeply(
    ObjectDB::Finder->_normalize_with([qw/hello foo.bar/]),
    [foo => {columns => [], nested => [bar => {}]}, hello => {}]
);
is_deeply(
    ObjectDB::Finder->_normalize_with([hello => {a => 'b'}, qw/foo.bar.baz/]),
    [   foo => {
            columns   => [],
            nested => [bar => {columns => [], nested => [baz => {}]}]
        },
        hello => {a => 'b'}
    ]
);

is_deeply(
    ObjectDB::Finder->_normalize_with(
        [qw/articles.comments.sub_comments articles.main_category/]
    ),
    [   'articles',
        {   'columns'   => [],
            'nested' => [
                'comments',
                {   'columns'   => [],
                    'nested' => ['sub_comments', {}]
                },
                'main_category',
                {}
            ]
        }
    ]
);
