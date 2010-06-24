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

    my $class = $namespace . ObjectDB::Util->camelize($name);

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
