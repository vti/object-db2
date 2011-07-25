package ObjectDB::Updater;

use strict;
use warnings;

use base 'ObjectDB::Base';

use constant DEBUG => $ENV{OBJECTDB_DEBUG} || 0;

use ObjectDB::SQL::Update;

sub conn   { $_[0]->{conn} }
sub schema { $_[0]->{schema} }

sub update {
    my $self = shift;

    return $self->_update_instance(@_) unless $self->{columns}->is_empty;

    return $self->_update_objects(@_);
}

sub sql {
    my $self = shift;

    $self->{sql} ||= ObjectDB::SQL::Update->new;

    return $self->{sql};
}

sub _update_instance {
    my $self   = shift;
    my %params = @_;

    return $self unless $self->{columns}->is_modified;

    my $conn = $self->conn;

    my @primary_or_unique_key = $self->{columns}->pk_or_uk_columns;

    Carp::croak q/->update: no primary or unique keys specified/
      unless @primary_or_unique_key;

    my @columns = $self->{columns}->regular_columns;
    my @values = map { $self->{columns}->get($_) } @columns;

    my $sql = $self->sql;
    $sql->table($self->schema->table);
    $sql->columns(\@columns);
    $sql->values(\@values);
    $sql->where(map { $_ => $self->{columns}->get($_) } @primary_or_unique_key);

    warn "$sql" if DEBUG;

    $self->conn->run(
        sub {
            my $dbh = shift;

            my $sth = $dbh->prepare("$sql");
            return unless $sth;

            my $rv = $sth->execute(@{$sql->bind});
            return unless $rv && $rv eq '1';

            $self->{columns}->not_modified;
        }
    );

    return $self;
}

sub _update_objects {
    my $self   = shift;
    my %params = @_;

    my $conn = $self->conn;

    my %set     = @{$params{set}};
    my @columns = keys %set;
    my @values  = values %set;

    my $sql = $self->sql;
    $sql->table($self->schema->table);
    $sql->columns(\@columns);
    $sql->values(\@values);
    $sql->where($params{where});

    if ($ENV{OBJECTDB_DEBUG}) {
        warn "$sql";
        warn join(', ', @{$sql->bind});
    }

    return $conn->run(
        sub {
            my $dbh = shift;

            my $sth = $dbh->prepare("$sql");
            return unless $sth;

            my $rv = $sth->execute(@{$sql->bind});
            return unless $rv;

            return 0 if $rv eq '0E0';

            return $rv;
        }
    );
}

1;
