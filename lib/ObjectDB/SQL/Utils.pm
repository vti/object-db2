package ObjectDB::SQL::Utils;

use strict;
use warnings;

sub import {
    my $class     = shift;
    my @functions = @_;

    my $caller = caller;
    no strict 'refs';
    no warnings 'redefine';

    foreach my $func (@functions) {
        *{"${caller}::$func"} = \&{$func};
    }
}

sub prepare_column {
    my ($column, $prefix, $quote) = @_;

    # Prefixed
    if ($column =~ s/^(\w+)\.//) {
        $column = escape($1, $quote) . '.' . escape($column, $quote);
    }

    # Default prefix
    elsif ($prefix) {
        $column = escape($prefix, $quote) . '.' . escape($column, $quote);
    }

    # No Prefix
    else {
        $column = escape($column, $quote);
    }

    return $column;
}

sub escape {
    my ($value, $quote) = @_;

    $quote ||= '`';

    $value =~ s/$quote/\\$quote/g;

    return "$quote$value$quote";
}

1;
