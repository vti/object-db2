package ObjectDB::SQL::Utils;

use strict;
use warnings;

sub import {
    my $class = shift;
    my @functions = @_;

    my $caller = caller;
    no strict 'refs';
    no warnings 'redefine';

    foreach my $func (@functions) {
        *{"${caller}::$func"} = \&{$func};
    }
}

sub prepare_column {
    my $column  = shift;
    my $default = shift;

    # Prefixed
    if ($column =~ s/^(\w+)\.//) {
        $column = escape($1) . '.' . escape($column);
    }

    # Default prefix
    elsif ($default) {
        $column = escape($default) . '.' . escape($column);
    }

    # No Prefix
    else {
        $column = escape($column);
    }

    return $column;
}

sub escape {
    my $value = shift;

    $value =~ s/`/\\`/g;

    return "`$value`";
}

1;
