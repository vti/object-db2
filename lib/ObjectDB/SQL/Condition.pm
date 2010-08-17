package ObjectDB::SQL::Condition;

use strict;
use warnings;

use base 'ObjectDB::Base';
use ObjectDB::SQL::Select;

__PACKAGE__->attr(logic => 'AND');


sub _build {
    my $self   = shift;
    my $params = shift;

    my $string = "";

    my $condition = ref $params->{condition} ? $params->{condition}
      : [$params->{condition}];
    my $prefix    = $params->{prefix};
    my $driver    = $params->{driver};

    my $count = 0;
    while (my ($key, $value) = @{$condition}[$count, $count + 1]) {
        last unless $key;

        $string .= " ".$self->logic." " unless $count == 0;
        if (ref $key eq 'SCALAR') {
            $string .= $$key;

            $count++;
        }
        else {
            my $concat;

            # -concat(col1,col2...)
            if ($key =~/^-concat\(([\w,]+)\)/){
                $concat = $1;
            }

            # -and -or
            if ($key =~ s/^-//) {
                if ($key eq 'or' || $key eq 'and') {
                    $self->logic(uc $key);
                    $string .= $self->_build({
                        condition => $value,
                        prefix    => $prefix,
                        driver    => $driver
                    });
                    last;
                }
            }

            # Process key
            if ( $concat ){
                my @concat = split (/,/,$concat);
                foreach my $concat (@concat){
                    $concat = $self->escape( $concat );

                    if ($prefix) {
                        $concat = $self->escape($prefix).'.'.$concat;
                    }
                }

                $driver || die 'no sql driver defined';

                if ( $driver eq 'SQLite' ){
                    $key = join(' || "__" || ', @concat);
                }
                elsif ( $driver eq 'mysql' ){
                    $key = 'CONCAT_WS("__",'.join(',', @concat).')';
                }
            }
            else {
                $key = ObjectDB::SQL::Select
                  ->prepare_column($key,$prefix);
            }

            # Process value
            if (defined $value) {
                if (ref $value eq 'HASH') {
                    my ($op, $val) = %$value;

                    if (defined $val) {
                        $string .= "$key $op ?";
                        $self->bind( $val );
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
                        $self->bind( $v );
                    }

                    $string .= ")";
                }
                elsif (ref $value) {
                    $string .= "$key = $$value";
                }
                else {
                    $string .= "$key = ?";
                    $self->bind( $value );
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

sub escape {
    my $self = shift;
    my $value = shift;

    $value =~ s/`/\\`/g;

    return "`$value`";
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

    return $self;
}


1;
