package Message;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->belongs_to(
    'sender',
    foreign_class => 'Identificator',
    map           => {sender_id => 'id'},
  )->belongs_to(
    'recipient',
    foreign_class => 'Identificator',
    map           => {recipient_id => 'id'},
  );

1;
