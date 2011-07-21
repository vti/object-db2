# Copied from Mojo::Base
# Copyright (C) 2008-2010, Sebastian Riedel.

package ObjectDB::Base;

use strict;
use warnings;

# No imports because we get subclassed, a lot!
require Carp;

# Kids, you tried your best and you failed miserably.
# The lesson is, never try.
sub new {
    my $class = shift;

    # Instantiate
    my $self = bless
      exists $_[0] ? exists $_[1] ? {@_} : {%{$_[0]}} : {},
      ref $class || $class;

    $self->BUILD;

    return $self;
}

sub BUILD {
}

# Performance is very important for something as often used as accessors,
# so we optimize them by compiling our own code, don't be scared, we have
# tests for every single case
sub attr {
    my $class   = shift;
    my $attrs   = shift;
    my $default = shift;

    # Check for more arguments
    Carp::croak('Attribute generator called with too many arguments') if @_;

    # Shortcut
    return unless $class && $attrs;

    # Check default
    Carp::croak('Default has to be a code reference or constant value')
      if ref $default && ref $default ne 'CODE';

    # Allow symbolic references
    no strict 'refs';

    # Create attributes
    $attrs = ref $attrs eq 'ARRAY' ? $attrs : [$attrs];
    my $ws = '    ';
    for my $attr (@$attrs) {

        Carp::croak(qq/Attribute "$attr" invalid/)
          unless $attr =~ /^[a-zA-Z_]\w*$/;

        # Header
        my $code = "sub {\n";

        # No value
        $code .= "${ws}if (\@_ == 1) {\n";
        unless (defined $default) {

            # Return value
            $code .= "$ws${ws}return \$_[0]->{'$attr'};\n";
        }
        else {

            # Return value
            $code .= "$ws${ws}return \$_[0]->{'$attr'} ";
            $code .= "if exists \$_[0]->{'$attr'};\n";

            # Return default value
            $code .= "$ws${ws}return \$_[0]->{'$attr'} = ";
            $code .=
              ref $default eq 'CODE'
              ? '$default->($_[0])'
              : '$default';
            $code .= ";\n";
        }
        $code .= "$ws}\n";

        # Store value
        $code .= "$ws\$_[0]->{'$attr'} = \$_[1];\n";

        # Return invocant
        $code .= "${ws}return \$_[0];\n";

        # Footer
        $code .= '};';

        # We compile custom attribute code for speed
        *{"${class}::$attr"} = eval $code;

        # This should never happen (hopefully)
        Carp::croak("ObjectDB::Base compiler error: \n$code\n$@\n") if $@;

        # Debug mode
        if ($ENV{OBJECTDB_BASE_DEBUG}) {
            warn "\nATTRIBUTE: $class->$attr\n";
            warn "$code\n\n";
        }
    }
}

1;
