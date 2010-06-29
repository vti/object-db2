package ObjectDB::Relationship::Base;

use strict;
use warnings;

use base 'ObjectDB::Base';

__PACKAGE__->attr([qw/name foreign_class foreign_table/]);
__PACKAGE__->attr([qw/map/]                  => sub { {} });
__PACKAGE__->attr([qw/with where join_args/] => sub { [] });
__PACKAGE__->attr(is_built => 0);

use ObjectDB::Util;

sub type { ObjectDB::Util->decamelize((split '::' => ref(shift))[-1]) }

sub class {
    my $self = shift;

    my $class = $self->{class};

    ObjectDB::Loader->load($class);

    return $self->{class};
}

sub table {
    my $self = shift;

    return $self->{table} if $self->{table};

    $self->{table} = ObjectDB::Util->class_to_table($self->class);

    return $self->{table};
}

sub build {
    my $self = shift;

    return if $self->is_built;

    unless ($self->class->can($self->name)) {
        no strict;
        my $class = $self->class;
        my $name = $self->name;
        my $code = "sub {shift->related('$name')}";
        *{"${class}::$name"} = eval $code;
    }

    $self->_build(@_);

    $self->is_built(1);
}

sub is_belongs_to              { shift->is_type('belongs_to') }
sub is_belongs_to_one          { shift->is_type('belongs_to_one') }
sub is_has_and_belongs_to_many { shift->is_type('has_and_belongs_to_many') }
sub is_has_many                { shift->is_type('has_many') }
sub is_has_one                 { shift->is_type('has_one') }

sub is_type {
    my $self = shift;

    return (grep { $_ eq $self->type } @_) ? 1 : 0;
}

sub _build {}

1;
