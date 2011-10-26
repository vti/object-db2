package UpdateTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use Article;

sub update : Test {
    my $article = Article->new->create;
    my $id = $article->id;

    $article->title('foo');
    $article->update;

    $article->load(id => $id);

    is($article->title, 'foo');
}

sub do_nothing_when_nothing_is_updated : Test {
    my $article = Article->new;

    $article->update;

    ok($article);
}

sub die_when_updating_without_primary_key : Test {
    my $article = Article->new;

    $article->title('foo');

    eval { $article->update };

    like($@, qr/->update: no primary or unique keys specified/);
}

1;
