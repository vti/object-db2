package ObjectDB::SQL::Factory;

use strict;
use warnings;

use Class::Load ();

sub new {
    my $class    = shift;
    my $name     = shift;
    my (%params) = @_;

    die 'dbh is required' unless $params{dbh};

    $name =
      'ObjectDB::SQL::' . $name . '::' . $params{dbh}->{Driver}->{Name};

    Class::Load::load_class($name);

    return $name->new(%params);
}

1;
