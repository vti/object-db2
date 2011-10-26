package ColumnTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use Article;

sub is_undef_by_default : Test {
    my $article = Article->new;

    ok(not defined $article->column('title'));
}

sub set_column : Test {
    my $article = Article->new;

    $article->column(title => 'bar');

    is($article->column('title'), 'bar');
}

sub set_undef : Test {
    my $article = Article->new;

    $article->column(title => 'bar');
    $article->column(title => undef);

    ok(not defined $article->column('title'));
}

1;
