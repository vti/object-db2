package Article;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema->belongs_to('author')->has_and_belongs_to_many('tags')
  ->has_many('comments')->has_many('to_do_articles')
  ->belongs_to('special_report')->belongs_to('main_category')
  ->has_many('images', map => {img_number => 'img_num'} );
1;
