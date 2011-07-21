package ObjectDB::Relationship::Proxy;

use strict;
use warnings;

use base 'ObjectDB::Relationship::Base';

sub proxy_key { @_ > 1 ? $_[0]->{map_class} = $_[1] : $_[0]->{map_class} }

1;
