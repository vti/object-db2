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

1;
