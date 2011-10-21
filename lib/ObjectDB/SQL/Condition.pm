package ObjectDB::SQL::Condition;

use strict;
use warnings;

use base 'ObjectDB::Base';

use ObjectDB::SQL::Utils qw/escape prepare_column/;

sub BUILD {
    my $self = shift;
    $self->{logic}  = 'AND' if not exists $self->{logic};
    $self->{prefix} = ''    if not exists $self->{prefix};
    $self->{driver} = ''    if not exists $self->{driver};
}

sub prefix { @_ > 1 ? $_[0]->{prefix} = $_[1] : $_[0]->{prefix} }
sub driver { @_ > 1 ? $_[0]->{driver} = $_[1] : $_[0]->{driver} }
sub logic  { @_ > 1 ? $_[0]->{logic}  = $_[1] : $_[0]->{logic} }

use overload '""' => sub { shift->to_string }, fallback => 1;

sub cond {
    my $self = shift;

    unless (@_) {
        return unless ref($self->{cond}) eq 'ARRAY';
        return $self->{cond};
    }

    return unless defined $_[0] && $_[0] ne '';

    if (ref $_[0] eq 'ARRAY') {
        push @{$self->{cond}}, @{$_[0]};
    }
    elsif (ref $_[0] eq 'SCALAR') {
        push @{$self->{cond}}, shift;
    }
    elsif (!ref $_[0] && defined $_[0]) {
        push @{$self->{cond}}, @_;
    }
    else {
        Carp::croak("Unexpected parameter: "
              . ref($_[0])
              . " (\"$_[0]\"). cond() accepts reference to array/scalar or array of parameters!"
        );
    }

    return $self;
}

sub bind {
    my $self = shift;

    return $self->{_bind} || $self->{bind} || [] unless @_;

    if (ref $_[0] eq 'ARRAY') {
        push @{$self->{bind}}, @{$_[0]};
    }
    else {
        push @{$self->{bind}}, $_[0];
    }

    return $self;
}

sub add_bind {
    my $self = shift;

    if (ref $_[0] eq 'ARRAY') {
        push @{$self->{_bind}}, @{$_[0]};
    }
    else {
        push @{$self->{_bind}}, $_[0];
    }

    return $self;
}

sub build {
    my $self = shift;

    my $cond = $self->cond;
    $cond = [$cond] unless ref $cond eq 'ARRAY';

    my $prefix = $self->{prefix};
    my $driver = $self->{driver};

    $self->{_bind} = $self->{bind};

    return $self->_build($self->logic, $cond, $prefix);
}

sub _build {
    my $self = shift;
    my ($logic, $cond, $prefix) = @_;

    $cond = [$cond] unless ref $cond eq 'ARRAY';

    my $string = "";

    my $count = 0;
    while (my ($key, $value) = @{$cond}[$count, $count + 1]) {
        last unless $key;

        $string .= " " . $logic . " " unless $count == 0;
        if (ref $key eq 'SCALAR') {
            $string .= $$key;

            $count++;
        }
        else {
            my $concat;

            # -concat(col1,col2...)
            if ($key =~ /^-concat\(([\w,]+)\)/) {
                $concat = $1;
            }

            # -and -or
            if (my $new_logic = $self->logic_switched($key)) {
                $string .= $self->_build($new_logic, $value, $prefix);
                $count += 2;
                next;
            }

            # Process key
            if ($concat) {
                my @concat = split(/,/, $concat);
                foreach my $concat (@concat) {
                    $concat = escape($concat);

                    if ($prefix) {
                        $concat = escape($prefix) . '.' . $concat;
                    }
                }

                my $driver = $self->{driver} || die 'no sql driver defined';

                if ($driver =~ /SQLite/) {
                    $key = join(' || "__" || ', @concat);
                }
                elsif ($driver =~ /mysql/) {
                    $key = 'CONCAT_WS("__",' . join(',', @concat) . ')';
                }
                else {
                    die 'unknown driver (supported drivers: SQLite, mysql)';
                }
            }
            else {
                $key = prepare_column($key, $prefix);
            }

            $string .= $self->_build_value($key, $value);

            $count += 2;
        }
    }

    return unless $string;

    return "($string)";
}

sub _build_value {
    my $self = shift;
    my ($key, $value) = @_;

    return $self->_build_not_null_value($key, $value) if defined $value;

    return $self->_build_null_value($key);
}

sub _build_not_null_value {
    my $self = shift;
    my ($key, $value) = @_;

    if (ref $value eq 'HASH') {
        return $self->_build_hashref_value($key, $value);
    }
    elsif (ref $value eq 'ARRAY') {
        return $self->_build_arrayref_value($key, $value);
    }
    elsif (ref $value) {
        return $self->_build_scalarref_value($key, $value);
    }

    return $self->_build_string_value($key, $value);
}

sub _build_null_value {
    my $self = shift;
    my $key  = shift;

    return "$key IS NULL";
}

sub _build_hashref_value {
    my $self = shift;
    my ($key, $value) = @_;

    my ($op, $val) = %$value;

    if (defined $val) {
        if (ref $val) {
            return "$key $op $$val";
        }
        else {
            $self->add_bind($val);
            return "$key $op ?";
        }
    }
    else {
        return "$key IS $op NULL";
    }

    return '';
}

sub _build_arrayref_value {
    my $self = shift;
    my ($key, $value) = @_;

    my $string = "$key IN (";

    my $first = 1;
    foreach my $v (@$value) {
        $string .= ', ' unless $first;
        $string .= '?';
        $first = 0;
        $self->add_bind($v);
    }

    $string .= ")";

    return $string;
}

sub _build_scalarref_value {
    my $self = shift;
    my ($key, $value) = @_;

    return "$key = $$value";
}

sub _build_string_value {
    my $self = shift;
    my ($key, $value) = @_;

    $self->add_bind($value);
    return "$key = ?";
}

sub logic_switched {
    my $self = shift;
    my ($key) = @_;

    if ($key =~ s/^-//) {
        if ($key eq 'or' || $key eq 'and') {
            return uc $key;
            #$self->{logic} = uc $key;
            #return 1;
        }
    }

    return;
}

sub to_string {
    my $self = shift;

    my $string = $self->build;
    return "$string" if $string;

    return '';
}

1;
