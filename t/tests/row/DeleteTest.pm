package DeleteTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use Article;

sub delete : Test {
    my $article = Article->new->create;
    my $id      = $article->id;

    $article->delete;

    ok(!$article->load(id => $id));
}

sub die_when_deleting_without_primary_key : Test {
    my $article = Article->new;

    eval { $article->delete };

    like($@, qr/->delete: no primary or unique keys specified/);
}

1;
