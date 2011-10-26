package FindPageTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use TestEnv;
use Article;

sub set_up : Test(setup) {
    TestEnv->clear_table(qw/articles/);
}

sub find_first_with_page : Test {
    Article->new(columns => {title => 'bar'})->create;
    Article->new(columns => {title => 'foo'})->create;
    Article->new(columns => {title => 'baz'})->create;

    my @articles = Article->table->find(page => 1, page_size => 2);

    is(@articles, 2);
}

1;
