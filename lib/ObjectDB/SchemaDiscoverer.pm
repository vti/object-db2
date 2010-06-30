package ObjectDB::SchemaDiscoverer;

use strict;
use warnings;

sub build {
    my $class = shift;
    my %params = @_;

    my $driver = delete $params{driver};

    my $driver_class = __PACKAGE__ . '::' . $driver;

    unless ($driver_class->can('new')) {
        eval "require $driver_class";
        die $@ if $@;
    }

    return $driver_class->new(%params);
}

1;
