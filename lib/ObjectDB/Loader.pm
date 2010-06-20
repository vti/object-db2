package ObjectDB::Loader;

use strict;
use warnings;

require Carp;

sub load {
    shift;

    foreach my $name (@_) {
        next unless $name;

        unless ($name->can('isa')) {
            eval "require $name";

            Carp::croak qq/Error while loading $name: $@/ if $@;
        }
    }

    return 1;
}

1;
