package TestSQLBase;

use strict;
use warnings;

use base 'TestBase';

use Scalar::Util qw(refaddr);

use TestEnv;
use TestDB;

sub driver {''}

sub startup : Test(startup) {
    my $self = shift;

    if ($self->driver ne TestDB->dbh->{Driver}->{Name}) {
        # TODO
    }
    else {
        $self->SUPER::startup(@_);
    }
}

sub shutdown : Test(shutdown) {
    my $self = shift;

    $self->SUPER::shutdown(@_);
}


1;
