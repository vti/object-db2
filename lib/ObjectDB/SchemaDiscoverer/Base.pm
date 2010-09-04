package ObjectDB::SchemaDiscoverer::Base;

use strict;
use warnings;

use base 'ObjectDB::Base';

__PACKAGE__->attr([qw/table/]);
__PACKAGE__->attr([qw/columns primary_key unique_keys/] => sub { [] });
__PACKAGE__->attr('auto_increment');

sub unquote {
    my $self  = shift;
    my $value = shift;

    $value =~ s/^\`//;
    $value =~ s/\`$//;

    return $value;
}


1;
