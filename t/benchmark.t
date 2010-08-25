#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN {
    plan skip_all => "set TEST_BENCHMARK to run this test"
      unless $ENV{TEST_BENCHMARK};
}

plan tests => 1;

use lib 't/lib';

use TestEnv;
use Benchmark qw/:hireswallclock/;

TestEnv->setup;

use Author;
use Comment;

warn "\n\n";


# Create
my $b_start = Benchmark->new;
for (my $i = 1; $i <= 100; $i++) {

    my @author = (
        name     => "foo $i",
        articles => [
            {   title    => 'article 1-1',
                comments => [
                    {   content       => 'comment 1-1-1',
                        creation_date => '2005-12-01',
                        sub_comments  => [
                            {content => 'sub comment 1-1-1-1'},
                            {content => 'sub comment 1-1-1-2'}
                        ],
                    },
                    {   content       => 'comment 1-1-2',
                        creation_date => '2008-12-21'
                    },
                    {   content       => 'comment 1-1-3',
                        creation_date => '2009-11-21'
                    },
                    {   content       => 'comment 1-1-4',
                        creation_date => '2008-12-21'
                    },
                    {   content       => 'comment 1-1-5',
                        creation_date => '2010-01-01'
                    },
                    {   content       => 'comment 1-1-6',
                        creation_date => '2007-03-04'
                    }

                ]
            },
            {title => 'article 1-2'},
            {   title    => 'article 1-3',
                comments => [
                    {   content       => 'comment 1-3-1',
                        creation_date => '2005-12-01'
                    }
                ]
            },
            {   title          => 'article 1-4',
                to_do_articles => [{to_do => 'to do 4'}]
            }
        ]
    );

    Author->create(@author);
    warn "Memory:" . memory();

}
my $b_stop = Benchmark->new;
my $b_diff = timediff($b_stop, $b_start);
warn "create 100 authors, 400 articles, 700 comments:\n"
  . timestr($b_diff) . "\n\n";


### Find
$b_start = Benchmark->new;
for (my $i = 1; $i <= 100; $i++) {
    my @comments = Comment->find;
    warn "Memory:" . memory();
}
$b_stop = Benchmark->new;
$b_diff = timediff($b_stop, $b_start);
warn "find all:\n" . timestr($b_diff) . "\n\n";


# Find using "with"
$b_start = Benchmark->new;
for (my $i = 1; $i <= 100; $i++) {
    my @authors = Author->find(with => [qw/articles.comments/]);
    warn "Memory:" . memory();
}
$b_stop = Benchmark->new;
$b_diff = timediff($b_stop, $b_start);
warn "find all:\n" . timestr($b_diff) . "\n\n";


### Delete
$b_start = Benchmark->new;
Author->delete;
$b_stop = Benchmark->new;
$b_diff = timediff($b_stop, $b_start);
warn "delete all the data:\n" . timestr($b_diff) . "\n\n";


ok(1);


### show memory
sub memory {
    my $class = shift;

    if ($^O eq 'MSWin32') {
        require Win32::Process::Memory;
        my $proc = Win32::Process::Memory->new({pid => $$});
        return $proc->get_memtotal / 1024;
    }
    else {
        my $mem = qx(ps -ovsz= -p$$);
        chomp($mem);
        return $mem;
    }
}

TestEnv->teardown;
