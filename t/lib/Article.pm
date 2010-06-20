package Article;

use strict;
use warnings;

use base 'ObjectDB';

__PACKAGE__->schema
  ->belongs_to('author')
  ->has_and_belongs_to_many('tags');

    #relationships => {
        #category => {
            #type  => 'many to one',
            #class => 'Category',
            #map   => {category_id => 'id'}
        #},
        #tags => {
            #type      => 'many to many',
            #map_class => 'ArticleTagMap',
            #map_from  => 'article',
            #map_to    => 'tag'
        #},
        #comments => {
            #type  => 'one to many',
            #class => 'Comment',
            #where => [type => 'article'],
            #map   => {id => 'master_id'}
        #}
    #}

1;
