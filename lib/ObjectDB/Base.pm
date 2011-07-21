package ObjectDB::Base;

use strict;
use warnings;

sub new {
    my $class = shift;
    my %params = @_ == 1 && ref $_[0] eq 'HASH' ? %{$_[0]} : @_;

    my $self = {%params};
    bless $self, $class;

    $self->BUILD;

    return $self;
}

sub BUILD { }

1;
