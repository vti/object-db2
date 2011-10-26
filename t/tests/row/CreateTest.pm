package CreateTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use Article;

sub create_new_row : Test {
    my $article = Article->new->create;

    ok($article->load(id => $article->id));
}

sub auto_increment_column_is_correctly_set : Test {
    my $id1 = Article->new->create->id;
    my $id2 = Article->new->create->id;

    ok($id2 > $id1);
}

1;
