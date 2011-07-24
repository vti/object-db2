package AuthorData;

use strict;
use warnings;

use Author;
use MainCategory;

### Related classes are loaded automatically
#use Article;
#use Comment;
#use SubComment;
use SpecialReport;


###### Using columns for mapping that do not follow naming conventions
###### Using columns for mapping that are not primary key columns
###### Map tables using multiple columns

sub populate {
    my $class = shift;

    # Create data
    my $author = Author->new->create(
        name     => 'author 1',
        articles => [
            {   title    => 'article 1-1',
                comments => [
                    {   content       => 'comment 1-1-1',
                        creation_date => '2005-12-01',
                        sub_comments  => [
                            {content => 'sub comment 1-1-1-1'},
                            {content => 'sub comment 1-1-1-2'}
                        ],
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

                ]
            },
            {   title    => 'article 1-2',
                tags     => [   {   name=>'Tag1'},
                                {   name=>'Tag2'},
                                {   name => 'Tag3',
                                    admin_histories => [{
                                        admin_name => 'Andre2',
                                        from       => '2010-02-01',
                                        till       => '2010-03-01'
                                    }]

                                }
                            ]
            },
            {   title    => 'article 1-3',
                comments => [
                    {   content       => 'comment 1-3-1',
                        creation_date => '2005-12-01'
                    }
                ]
            },
            {   title          => 'article 1-4',
                to_do_articles => [{to_do => 'to do 4'}],
                tags           => [{name=>'Tag4'},{name=>'Tag5'}]
            }
        ]
    );


    my $author2 = Author->new->create(
        name     => 'author 2',
        articles => [
            {   title    => 'article 2-1',
                comments => [
                    {   content       => 'comment 2-1-1',
                        creation_date => '2005-07-31',
                        sub_comments  => [
                            {content => 'sub comment 2-1-1-1'},
                            {content => 'sub comment 2-1-1-2'}
                        ]
                    },
                    {   content       => 'comment 2-1-2',
                        creation_date => '2004-06-04'
                    }
                ],
                tags => [{name=>'Tag10'},{name=>'Tag11'}]
            },
            {title => 'article 2-2'},
            {   title    => 'article 2-3',
                comments => [
                    {   content       => 'comment 2-3-1',
                        creation_date => '2011-12-01'
                    }
                ]
            },
            {   title          => 'article 2-4',
                to_do_articles => [{to_do => 'to do 4'}]
            }
        ]
    );


    # main category
    my $category_1 = MainCategory->new->create(title => 'main category 1');
    my $category_2 = MainCategory->new->create(title => 'main category 2');
    my $category_3 = MainCategory->new->create(title => 'main category 3');
    my $category_4 = MainCategory->new->create(
        title           => 'main category 4',
        admin_histories => [
            {   admin_name => 'Andre1',
                from       => '2010-01-01',
                till       => '2010-02-01'
            },
            {   admin_name => 'Andre2',
                from       => '2010-02-01',
                till       => '2010-03-01'
            }

        ]
    );

    # special report
    my $special_report_1 = SpecialReport->new->create(title => 'special report 1');



    $author->articles->[0]
      ->column('main_category_id' => $category_4->column('id'))->update;


    # 3rd article -> belongs to special report 1 -> belongs to main category 4
    $author->articles->[2]
      ->column('special_report_id' => $special_report_1->column('id'))
      ->update;
    $special_report_1->column(main_category_id => $category_4->column('id'))
      ->update;

    return ($author, $author2);

}

sub cleanup {
    my $class = shift;

    Author->new->delete(all => 1);
    MainCategory->new->delete(all => 1);
}


1;
