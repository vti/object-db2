package ObjectDB::SchemaDiscoverer;

use strict;
use warnings;

require Carp;
use Class::Load ();

sub build {
    my $class  = shift;
    my %params = @_;

    my $driver = delete $params{driver};

    Carp::croak 'driver is required' unless $driver;

    my $driver_class = __PACKAGE__ . '::' . $driver;

    Class::Load::load_class($driver_class);

    return $driver_class->new(%params);
}

1;
