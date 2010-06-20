package ObjectDB::Util;

use strict;
use warnings;

sub camelize {
    shift;
    my $string = shift;

    my @parts;
    foreach my $module (split '-' => $string) {
        push @parts, join '' => map {ucfirst} split _ => $module;
    }

    return join '::' => @parts;
}

sub decamelize {
    shift;
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
    shift;
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
    shift;
    my $string = shift;

    if ($string =~ s/(?<!(?:a|e|o|i))y//) {
        $string .= 'ie';
    }

    $string .= 's';

    return $string;
}

sub class_to_table {
    my $class = shift;
    my $name = shift;

    $name = $class->decamelize($name);
    $name = $class->single_to_plural($name);

    return $name;
}

sub table_to_class {
    my $class = shift;
    my $name = shift;

    $name = $class->camelize($name);
    $name = $class->plural_to_single($name);

    return $name;
}

1;
