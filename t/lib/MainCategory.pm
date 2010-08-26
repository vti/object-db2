package MainCategory;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->has_many('articles')->has_many('admin_histories');

# Convention: inflator methods starts with "inflate_"
sub inflate_quote_title {
    my $self = shift;

    my $title = $self->column('title');
    $title = '"' . $title . '"';
    $self->{columns}->{quoted_title} = $title;

}


1;
