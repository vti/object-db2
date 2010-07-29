package ObjectDB::Connector;

use strict;
use warnings;

use base 'ObjectDB::Base';

__PACKAGE__->attr('dbh');

use constant DEBUG => $ENV{OBJECTDB_DEBUG} || 0;
use constant DBIXCONNECTOR => eval 'use DBIx::Connector 0.36; 1';

use DBI;

sub new {
    my $class = shift;

    return DBIx::Connector->new(@_) if DBIXCONNECTOR;

    my $self = {_args => [@_]};
    bless $self, $class;

    return $self;
}

sub driver {
    my $self = shift;

    return $self->dbh->{Driver}->{Name};
}

sub mode { }

sub in_txn { !shift->dbh->FETCH('AutoCommit') }

sub txn {
    my $self = shift;
    my $cb   = pop;

    my $dbh = $self->dbh;

    # Already in transaction
    return $cb->($dbh) if $self->in_txn;

    my $raise_error_bak = $dbh->{RaiseError};

    $dbh->{AutoCommit} = 0;
    $dbh->{RaiseError} = 1;

    my $wantarray = wantarray;

    warn 'BEGIN TRANSACTION' if DEBUG;
    my ($rv, @rv);
    if ($wantarray) {
        eval { @rv = $cb->($dbh) };
    }
    else {
        eval { $rv = $cb->($dbh) };
    }

    if ($@) {
        warn 'ROLLBACK' if DEBUG;
        $dbh->rollback;
        warn $DBI::errstr if $dbh->{PrintWarn};
        warn $DBI::errstr;
        die $DBI::errstr if $raise_error_bak;
        return;
    }

    warn 'COMMIT' if DEBUG;
    $dbh->commit;

    $dbh->{AutoCommit} = 1;
    $dbh->{RaiseError} = $raise_error_bak;

    return $wantarray ? @rv : $rv;
}

sub connect {
    my $self = shift;

    $self->dbh(DBI->connect(@{$self->{_args}}));

    return $self->dbh;
}

sub run {
    my $self = shift;
    my $cb = pop;

    Carp::croak qw/Callback is required/ unless $cb && ref $cb eq 'CODE';

    my $dbh = $self->dbh && $self->dbh->FETCH('Active') ? $self->dbh : undef;
    $dbh ||= $self->connect;

    local $_ = $dbh;
    return $cb->($dbh, wantarray);
}

1;
