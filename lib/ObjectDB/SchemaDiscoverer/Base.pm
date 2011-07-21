package ObjectDB::SchemaDiscoverer::Base;

use strict;
use warnings;

use base 'ObjectDB::Base';

sub table { $_[0]->{table} }

sub auto_increment {
    @_ > 1 ? $_[0]->{auto_increment} = $_[1] : $_[0]->{auto_increment};
}
sub columns { @_ > 1 ? $_[0]->{columns} = $_[1] : $_[0]->{columns} }

sub primary_key {
    @_ > 1 ? $_[0]->{primary_key} = $_[1] : $_[0]->{primary_key}
      || [];
}

sub unique_keys {
    @_ > 1 ? $_[0]->{unique_keys} = $_[1] : $_[0]->{unique_keys} || [];
}

sub unquote {
    my $self  = shift;
    my $value = shift;

    $value =~ s/^\`//;
    $value =~ s/\`$//;

    return $value;
}


1;
