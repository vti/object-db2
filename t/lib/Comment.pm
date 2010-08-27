package Comment;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->belongs_to('article')->belongs_to('author')
  ->has_many('sub_comments');


# Convention: inflator methods starts with "inflate_"
sub inflate_us_date_format {
    my $self = shift;

    my $creation_date = $self->column('creation_date');

    my @date = split('-', $creation_date);
    return unless @date;

    my @months = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
    my $date_formated =
      $months[$date[1] - 1] . ' ' . int($date[2]) . ',' . $date[0];

    $self->virtual_column(creation_date_formated => $date_formated);
}

1;
