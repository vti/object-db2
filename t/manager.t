#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;

use lib 't/lib';

use TestEnv;
use ObjectDB::Manager;

TestEnv->setup;

my $manager = ObjectDB::Manager->new;

my $author = $manager->create(Author => name => 'foo');
ok($author);

$author = $manager->find(Author => id => $author->id);
ok($author);

$author->delete;

my $article = $manager->create(articles => title => 'foo');
isa_ok($article, 'Article');
$article = $manager->find(articles => id => $article->id);
ok($article);
$article->delete;

TestEnv->teardown;
