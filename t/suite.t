#!/usr/bin/env perl

use lib 't/lib';

use TestLoader qw(t/tests);

Test::Class->runtests;
