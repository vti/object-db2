package TestSQLBase;

use strict;
use warnings;

use base 'TestBase';

use Scalar::Util qw(refaddr);
use Sub::Override;

use TestEnv;
use TestDB;

sub driver {''}

sub startup : Test(startup) {
    my $self = shift;

    if ($self->driver ne TestDB->dbh->{Driver}->{Name}) {
        no strict;
        no warnings 'redefine';
        #*{"Test::Class::_has_no_tests"} = sub {1};
        #*{"Test::Class::_run_method"} = sub {1};
        #*{"Test::Class::_total_num_tests"} = sub {0};

        #*{ref($self) . "::_has_no_tests"} = sub {1};
        #*{ref($self) . "::_run_method"} = sub {0};
        #*{ref($self) . "::_total_num_tests"} = sub {0};
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
