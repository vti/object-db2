package ObjectDB::SQL::Where;

use strict;
use warnings;

use base 'ObjectDB::Base';

__PACKAGE__->attr(qw/driver/);
__PACKAGE__->attr(is_built => 0);
__PACKAGE__->attr(prefix => '');
__PACKAGE__->attr(logic => 'AND');

use overload '""' => sub { shift->to_string }, fallback => 1;
use overload 'bool' => sub { shift; }, fallback => 1;

sub where {
    my $self = shift;

    unless (@_) {
        return unless ref($self->{where}) eq 'ARRAY';
        return $self->{where};
    }

    my @params;

    if (ref $_[0] eq 'ARRAY') {
        push @{$self->{where}}, @{$_[0]};
    }
    elsif (ref $_[0] eq 'SCALAR') {
        push @{$self->{where}}, shift;
    }
    elsif (!ref $_[0] && defined $_[0]) {
        push @{$self->{where}}, @_;
    }
    else {
        Carp::croak "Unexpected parameter: "
          . ref($_[0])
          . " (\"$_[0]\"). where() accepts reference to array/scalar or array of parameters!";
    }

    $self->is_built(0);

    return $self;
}

sub bind {
    my $self = shift;

    return $self->{bind} || [] unless @_;

    if (ref $_[0] eq 'ARRAY') {
        push @{$self->{bind}}, @{$_[0]};
    }
    else {
        push @{$self->{bind}}, $_[0];
    }

    $self->is_built(0);

    return $self;
}

sub _build {
    my $self = shift;

    my $string = "";

    # Direct value
    if (ref($_[0]) eq 'SCALAR') {
        return "($_[0])";
    }

    my $where = ref($_[0]) ? shift : \@_;

    my $count = 0;
    while (my ($key, $value) = @{$where}[$count, $count + 1]) {
        last unless $key;

        my $logic = $self->logic;
        $string .= " $logic " unless $count == 0;

        if (ref $key eq 'SCALAR') {
            $string .= $$key;

            $count++;
        }
        else {
            my $concat;

            # concat(col1,col2...)
            if ($key =~/^-concat\(([\w,]+)\)/){
                $concat = $1;
            }

            if ($key =~ s/^-//) {
                if ($key eq 'or' || $key eq 'and') {
                    $self->logic(uc $key);
                    $string .= $self->_build($value);
                    last;
                }
            }

            if ( $concat ){
                my @concat = split (/,/,$concat);
                foreach my $concat (@concat){
                    $concat = $self->escape( $concat );

                    if (my $prefix = $self->prefix) {
                        $concat = $self->escape($prefix).'.'.$concat;
                    }
                }

                $self->driver || die 'no sql driver defined';

                if ( $self->driver eq 'SQLite' ){
                    $key = join(' || "__" || ', @concat);
                }
                elsif ( $self->driver eq 'mysql' ){
                    $key = 'CONCAT_WS("__",'.join(',', @concat).')';
                }
            }
            # Prefixed key
            elsif ($key =~ s/\.(\w+)$//) {
                my $col = $1;
                $key = "`$key`.`$col`";
            }

            # Prefix
            elsif (my $prefix = $self->prefix) {
                $key = "`$prefix`.`$key`";
            }

            # No prefix
            else {
                $key = "`$key`";
            }

            if (defined $value) {
                if (ref $value eq 'HASH') {
                    my ($op, $val) = %$value;

                    if (defined $val) {
                        $string .= "$key $op ?";
                        $self->bind($val);
                    }
                    else {
                        $string .= "$key IS $op NULL";
                    }
                }
                elsif (ref $value eq 'ARRAY') {
                    $string .= "$key IN (";

                    my $first = 1;
                    foreach my $v (@$value) {
                        $string .= ', ' unless $first;
                        $string .= '?';
                        $first = 0;

                        $self->bind($v);
                    }

                    $string .= ")";
                }
                elsif (ref $value) {
                    $string .= "$key = $$value";
                }
                else {
                    $string .= "$key = ?";
                    $self->bind($value);
                }
            }
            else {
                $string .= "$key IS NULL";
            }

            $count += 2;
        }
    }

    return unless $string;

    return "($string)";
}

sub build {
    my $self = shift;

    $self->{to_string} = $self->_build($self->{where}) unless $self->is_built;

    $self->is_built(1);

    return $self->{to_string};
}

sub escape {
    my $self = shift;
    my $value = shift;

    $value =~ s/`/\\`/g;

    return "`$value`";
}

sub to_string {
    my $self = shift;

    my $string = $self->build;
    return " WHERE $string" if $string;

    return '';
}

1;
