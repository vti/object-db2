package ObjectDB::Manager;

use strict;
use warnings;

use base 'ObjectDB::Base';

__PACKAGE__->attr('conn');
__PACKAGE__->attr('namespace');

use ObjectDB::Util;
use ObjectDB::Loader;

our $AUTOLOAD;

sub name_to_class {
    my $self = shift;
    my $name = shift;

    return unless $name;

    my $namespace = $self->namespace;
    $namespace ||= '';

    my $class;

    if ($name =~ m/^[A-Z]/) {
        $class = $namespace . $name;
    }
    else {
        $class = $namespace . ObjectDB::Util->table_to_class($name);

        unless ($class->can('new')) {
            my $package = <<"EOF";
package $class;
use base 'ObjectDB';
__PACKAGE__->schema('$name');
1;
EOF

            eval $package;
            die qq/Couldn't initialize class "$class": $@/ if $@;
        }
    }

    ObjectDB::Loader->load($class);

    return $class;
}

sub AUTOLOAD {
    my $self = shift;
    my $name = shift;

    my $method = $AUTOLOAD;

    return unless $method;

    return if $method =~ /^[A-Z]+?$/;
    return if $method =~ /^_/;
    return if $method =~ /(?:\:*?)DESTROY$/;

    $method = (split '::' => $method)[-1];

    my $class = $self->name_to_class($name);
    return $class->$method(conn => $self->conn, @_);
}

1;
