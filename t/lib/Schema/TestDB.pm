package Schema::TestDB;

use strict;
use warnings;

use base 'TestDB';

sub rows_as_object {
    1;
}

sub namespace {
    return "Schema";
}


1;
