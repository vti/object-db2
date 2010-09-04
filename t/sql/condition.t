#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 28;

use_ok('ObjectDB::SQL::Condition');

my $cond;

$cond = ObjectDB::SQL::Condition->new;
is($cond->to_string, "");

$cond = ObjectDB::SQL::Condition->new;
$cond->cond([id => 2, title => 'hello']);
is($cond->to_string, "(`id` = ? AND `title` = ?)");
is_deeply($cond->bind, [qw/ 2 hello /]);
is($cond->to_string, "(`id` = ? AND `title` = ?)");
is_deeply($cond->bind, [qw/ 2 hello /], 'no side effects');

$cond = ObjectDB::SQL::Condition->new(prefix => 'foo');
$cond->cond([id => 2, title => 'hello']);
is($cond->to_string, "(`foo`.`id` = ? AND `foo`.`title` = ?)");
is_deeply($cond->bind, [qw/ 2 hello /]);

$cond = ObjectDB::SQL::Condition->new;
$cond->cond([id => [1, 2, 3]]);
is($cond->to_string, "(`id` IN (?, ?, ?))");
is_deeply($cond->bind, [qw/ 1 2 3 /]);

$cond = ObjectDB::SQL::Condition->new;
$cond->cond([\'foo.id = ?']);
$cond->bind(2);
is($cond->to_string, "(foo.id = ?)");
is_deeply($cond->bind, [2]);

$cond = ObjectDB::SQL::Condition->new;
$cond->cond([password => \"PASSWORD('foo')"]);
is($cond->to_string, "(`password` = PASSWORD('foo'))");
is_deeply($cond->bind, []);

$cond = ObjectDB::SQL::Condition->new;
$cond->cond([\'foo.id = 2', title => 'hello']);
is($cond->to_string, "(foo.id = 2 AND `title` = ?)");
is_deeply($cond->bind, [qw/ hello /]);

$cond = ObjectDB::SQL::Condition->new;
$cond->cond(['foo.id' => 2]);
is($cond->to_string, "(`foo`.`id` = ?)");
is_deeply($cond->bind, [qw/ 2 /]);

$cond = ObjectDB::SQL::Condition->new;
$cond->cond(
    [   -or => [
            'foo.id' => undef,
            -and     => ['foo.title' => 'boo', 'foo.content' => 'bar']
        ]
    ]
);
is($cond->to_string,
    "((`foo`.`id` IS NULL OR (`foo`.`title` = ? AND `foo`.`content` = ?)))");
is_deeply($cond->bind, ['boo', 'bar']);

$cond = ObjectDB::SQL::Condition->new;
$cond->logic('OR');
$cond->cond(['foo.id' => 2]);
is($cond->to_string, "(`foo`.`id` = ?)");
is_deeply($cond->bind, [qw/ 2 /]);

$cond = ObjectDB::SQL::Condition->new;
$cond->cond(['foo.id' => {'>' => 2}]);
is($cond->to_string, "(`foo`.`id` > ?)");
is_deeply($cond->bind, [qw/ 2 /]);

$cond = ObjectDB::SQL::Condition->new;
$cond->cond(['foo.id' => 2, \"a = 'b'"]);
is($cond->to_string, "(`foo`.`id` = ? AND a = 'b')");
is_deeply($cond->bind, [qw/ 2 /]);

$cond = ObjectDB::SQL::Condition->new;
$cond->cond([id => 2]);
$cond->cond(di => 3);
is($cond->to_string, "(`id` = ? AND `di` = ?)");
is_deeply($cond->bind, [qw/ 2 3 /]);
