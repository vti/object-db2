#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 28;

use_ok('ObjectDB::SQL::Where');

my $where;

$where = ObjectDB::SQL::Where->new;
is("$where", "");

$where = ObjectDB::SQL::Where->new;
$where->where([id => 2, title => 'hello']);
is("$where", " WHERE (`id` = ? AND `title` = ?)");
is_deeply($where->bind, [qw/ 2 hello /]);
is("$where", " WHERE (`id` = ? AND `title` = ?)");
is_deeply($where->bind, [qw/ 2 hello /]);

$where = ObjectDB::SQL::Where->new(prefix => 'foo');
$where->where([id => 2, title => 'hello']);
is("$where", " WHERE (`foo`.`id` = ? AND `foo`.`title` = ?)");
is_deeply($where->bind, [qw/ 2 hello /]);

$where = ObjectDB::SQL::Where->new;
$where->where([id => [1, 2, 3]]);
is("$where", " WHERE (`id` IN (?, ?, ?))");
is_deeply($where->bind, [qw/ 1 2 3 /]);

$where = ObjectDB::SQL::Where->new;
$where->where([\'foo.id = ?']);
$where->bind(2);
is("$where", " WHERE (foo.id = ?)");
is_deeply($where->bind, [2]);

$where = ObjectDB::SQL::Where->new;
$where->where([password => \"PASSWORD('foo')"]);
is("$where", " WHERE (`password` = PASSWORD('foo'))");
is_deeply($where->bind, []);

$where = ObjectDB::SQL::Where->new;
$where->where([\'foo.id = 2', title => 'hello']);
is("$where", " WHERE (foo.id = 2 AND `title` = ?)");
is_deeply($where->bind, [qw/ hello /]);

$where = ObjectDB::SQL::Where->new;
$where->where(['foo.id' => 2]);
is("$where", " WHERE (`foo`.`id` = ?)");
is_deeply($where->bind, [qw/ 2 /]);

$where = ObjectDB::SQL::Where->new;
$where->where([-or => ['foo.id' => undef, -and => ['foo.title' => 'boo', 'foo.content' => 'bar']]]);
is("$where", " WHERE ((`foo`.`id` IS NULL OR (`foo`.`title` = ? AND `foo`.`content` = ?)))");
is_deeply($where->bind, ['boo', 'bar']);

$where = ObjectDB::SQL::Where->new;
$where->condition->logic('OR');
$where->where(['foo.id' => 2]);
is("$where", " WHERE (`foo`.`id` = ?)");
is_deeply($where->bind, [qw/ 2 /]);

$where = ObjectDB::SQL::Where->new;
$where->where(['foo.id' => {'>' => 2}]);
is("$where", " WHERE (`foo`.`id` > ?)");
is_deeply($where->bind, [qw/ 2 /]);

$where = ObjectDB::SQL::Where->new;
$where->where(['foo.id' => 2, \"a = 'b'"]);
is("$where", " WHERE (`foo`.`id` = ? AND a = 'b')");
is_deeply($where->bind, [qw/ 2 /]);

$where = ObjectDB::SQL::Where->new;
$where->where([id => 2]);
$where->where(di => 3);
is("$where", " WHERE (`id` = ? AND `di` = ?)");
is_deeply($where->bind, [qw/ 2 3 /]);
