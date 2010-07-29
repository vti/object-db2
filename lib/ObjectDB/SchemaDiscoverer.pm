package ObjectDB::SchemaDiscoverer;

use strict;
use warnings;

require Carp;

sub build {
    my $class = shift;
    my %params = @_;

    my $driver = delete $params{driver};

    Carp::croak 'driver is required' unless $driver;

    my $driver_class = __PACKAGE__ . '::' . $driver;

    unless ($driver_class->can('new')) {
        eval "require $driver_class";
        Carp::croak qq/Error while loading $driver_class: $@/ if $@;
    }

    return $driver_class->new(%params);
}

1;
