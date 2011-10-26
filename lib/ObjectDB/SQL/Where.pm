package ObjectDB::SQL::Where;

use strict;
use warnings;

use base 'ObjectDB::SQL::Base';

use ObjectDB::SQL::Condition;

sub BUILD {
    my $self = shift;

    $self->{cond} = ObjectDB::SQL::Condition->new(dbh => $self->{dbh});

    return $self;
}

sub prefix {
    my $self = shift;

    return $self->{cond}->prefix(@_);
}

sub cond {
    my $self = shift;

    $self->{cond}->cond(@_);

    return $self;
}

sub bind {
    my $self = shift;

    return $self->{cond}->bind(@_);
}

sub to_string {
    my $self = shift;

    my $string = $self->{cond}->to_string;
    return '' if $string eq '';

    return " WHERE $string";
}

1;
