package FindTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use TestEnv;
use Article;
use Author;
use Message;

sub set_up : Test(setup) {
    TestEnv->clear_table(qw/articles authors messages/);
}

sub find_objects : Test {
    Article->new->create;

    my @articles = Article->table->find;

    ok(@articles);
}

sub find_objects_with_specific_fields : Test {
    my $id = Author->new(columns => {name => 'foo'})->create->id;

    my @authors = Author->table->find(columns => [qw/name/]);

    ok(not defined $authors[0]->password);
}

sub find_objects_with_all_fields : Test(2) {
    my $id =
      Author->new(columns => {name => 'foo', password => 'bar'})->create->id;

    my @authors = Author->table->find;

    is($authors[0]->name,     'foo');
    is($authors[0]->password, 'bar');
}

sub find_first_object : Test {
    Article->new(columns => {title => 'bar'})->create;
    Article->new(columns => {title => 'foo'})->create;

    my @articles = Article->table->find(first => 1);

    is(@articles, 1);
}

sub find_first_with_limit : Test {
    Article->new(columns => {title => 'bar'})->create;
    Article->new(columns => {title => 'foo'})->create;

    my @articles = Article->table->find(limit => 1);

    is(@articles, 1);
}

sub find_first_with_offset : Test {
    Article->new(columns => {title => 'bar'})->create;
    Article->new(columns => {title => 'foo'})->create;

    my @articles = Article->table->find(limit => 1, offset => 1);

    is($articles[0]->title, 'foo');
}

sub not_find_objects_when_table_is_empty : Test {
    my @articles = Article->table->find;

    ok(!@articles);
}

sub not_find_objects_when_query_is_wrong : Test {
    Article->new->create;

    my @articles = Article->table->find(where => [title => 'baz']);

    ok(!@articles);
}

sub find_objects_with_query : Test {
    Article->new(columns => {title => 'bar'})->create;
    Article->new(columns => {title => 'foo'})->create;

    my @articles = Article->table->find(where => [title => 'bar']);

    is(@articles, 1);
}

sub find_objects_with_order_by : Test(2) {
    Article->new(columns => {title => 'bar'})->create;
    Article->new(columns => {title => 'foo'})->create;

    my @articles = Article->table->find(order_by => 'title');

    is($articles[0]->title, 'bar');
    is($articles[1]->title, 'foo');
}

sub find_objects_with_group_by : Test {
    Article->new(columns => {title => 'foo'})->create;
    Article->new(columns => {title => 'foo'})->create;

    my @articles = Article->table->find(group_by => 'title');

    is(@articles, 1);
}

sub find_objects_without_primary_key : Test(2) {
    Message->new(
        columns => {sender_id => 1, recipient_id => 1, message => 'bar'})
      ->create;
    Message->new(
        columns => {sender_id => 2, recipient_id => 2, message => 'foo'})
      ->create;

    my @messages = Message->table->find(order_by => 'message');

    is($messages[0]->message, 'bar');
    is($messages[1]->message, 'foo');
}

1;
