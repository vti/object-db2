package Schema::AuthorData;

use strict;
use warnings;

use Schema::Author;

### Related classes are loaded automatically
#use Schema::Article;
#use Schema::Comment;


sub populate {
    my $class = shift;

    # Create data
    my $author = Schema::Author->new->create(
        name     => 'author 1',
        articles => [
            {   title    => 'article 1-1',
                comments => [
                    {   content       => 'comment 1-1-1',
                        creation_date => '2005-12-01'
                    },
                    {   content       => 'comment 1-1-2',
                        creation_date => '2008-12-21'
                    },
                    {   content       => 'comment 1-1-3',
                        creation_date => '2009-11-21'
                    },
                    {   content       => 'comment 1-1-4',
                        creation_date => '2008-12-21'
                    },
                    {   content       => 'comment 1-1-5',
                        creation_date => '2010-01-01'
                    },
                    {   content       => 'comment 1-1-6',
                        creation_date => '2007-03-04'
                    }

                ],
                tags => [{name => 'bar'}, {name => 'baz'}]
            },
            {title => 'article 1-2'},
            {   title    => 'article 1-3',
                comments => [
                    {   content       => 'comment 1-3-1',
                        creation_date => '2005-12-01'
                    }
                ]
            },
            {title => 'article 1-4'}
        ]
    );

    return ($author);

}

sub cleanup {
    my $class = shift;

    Schema::Author->new->delete(all => 1);
}


1;
