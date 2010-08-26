package ObjectDB::Utils;

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

sub camelize {
    my $string = shift;

    return unless $string;

    my @parts;
    foreach my $module (split '-' => $string) {
        push @parts, join '' => map {ucfirst} split _ => $module;
    }

    return join '::' => @parts;
}

sub decamelize {
    my $string = shift;

    my @parts;
    foreach my $module (split '::' => $string) {
        my @tokens = split '([A-Z])' => $module;
        my @p;
        foreach my $token (@tokens) {
            next unless defined $token && $token ne '';

            if ($token =~ m/[A-Z]/) {
                push @p, lc $token;
            }
            else {
                $p[-1] .= $token;
            }
        }

        push @parts, join _ => @p;
    }

    return join '-' => @parts;
}

sub plural_to_single {
    my $string = shift;

    if ($string =~ s/ies$//) {
        $string .= 'y';
    }
    else {
        $string =~ s/s$//;
    }

    return $string;
}

sub single_to_plural {
    my $string = shift;

    if ($string =~ s/(?<!(?:a|e|o|i))y$//) {
        $string .= 'ie';
    }

    $string .= 's';

    return $string;
}

sub class_to_table {
    my $class_name = shift;

    my @class_name_parts = split('::', $class_name);

    my $name = $class_name_parts[-1];

    $name = decamelize($name);
    $name = single_to_plural($name);

    return $name;
}

sub table_to_class {
    my $name = shift;

    $name = camelize($name);
    $name = plural_to_single($name);

    return $name;
}

1;
