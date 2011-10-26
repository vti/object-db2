package FindWithBelongsToTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use TestEnv;
use Article;
use Author;

sub set_up : Test(setup) {
    TestEnv->clear_table(qw/authors articles comments/);
}

sub find_objects_with_related : Test {
    my $author = Author->new->create;
    Article->new(columns => {author_id => $author->id})->create;

    my @articles = Article->table->find(with => 'author');

    is($articles[0]->author->id, $author->id);
}

sub find_objects_with_quering_related_objects : Test {
    my $author = Author->new(columns => {name => 'bar'})->create;
    Article->new(columns => {author_id => $author->id})->create;

    my @articles = Article->table->find(
        with  => 'author',
        where => ['author.name' => 'bar']
    );

    is($articles[0]->author->id, $author->id);
}

1;
