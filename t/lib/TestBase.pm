package TestBase;

use strict;
use warnings;

use base 'Test::Class';

use TestEnv;

sub startup : Test(startup) {
    TestEnv->setup;
}

sub shutdown : Test(shutdown) {
    TestEnv->teardown;
}


1;
