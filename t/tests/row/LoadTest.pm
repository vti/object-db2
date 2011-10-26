package LoadTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use TestEnv;
use Article;
use Author;

sub setup : Test(setup) {
    TestEnv->clear_table(qw/articles authors/);
}

sub load_object_inside : Test {
    my $article = Article->new->create;
    my $id      = $article->id;

    $article = Article->new->load(id => $id);

    is($article->id, $id);
}

sub load_object_form_db_by_primary_key : Test {
    my $article = Article->new->create;

    ok(Article->new->load(id => $article->id));
}

sub die_when_no_id_was_passed : Test {
    eval { Article->new->load };

    ok($@);
}

sub load_all_columns : Test(2) {
    my $author =
      Author->new(columns => {name => 'bar', password => 'baz'})->create;
    my $id = $author->id;

    $author = Author->new->load(id => $id);
    is($author->name,     'bar');
    is($author->password, 'baz');
}

sub load_with_specific_fields : Test {
    my $author =
      Author->new(columns => {name => 'bar', password => 'baz'})->create;
    my $id = $author->id;

    $author = Author->new->load(id => $id, columns => [qw/name/]);
    ok(not defined $author->password);
}

1;
