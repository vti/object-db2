#!/usr/bin/env perl

use lib 't/lib';

use TestLoader qw(t/tests/sql);

Test::Class->runtests;
