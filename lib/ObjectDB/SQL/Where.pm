package ObjectDB::SQL::Where;

use strict;
use warnings;

use base 'ObjectDB::Base';
use ObjectDB::SQL::Condition;

__PACKAGE__->attr(qw/driver/);
__PACKAGE__->attr(is_built => 0);
__PACKAGE__->attr(prefix => '');
__PACKAGE__->attr( condition => sub { ObjectDB::SQL::Condition->new } );

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

    if ( @_ ) {
        return $self->condition->bind(@_);
        $self->is_built(0);
    }
    else {
        return $self->condition->bind;
    }

}

sub _build {
    my $self = shift;

    my $params = ref $_[0] ? $_[0] : [@_];

    my $condition = $self->condition;

    my $string =
      $condition->_build({
        condition => $params,
        prefix    => $self->prefix,
        driver    => $self->driver
       });

    return $string;

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
