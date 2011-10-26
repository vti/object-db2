package ConditionTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use ObjectDB::SQL::Condition;

sub empty_string : Test(2) {
    my $self = shift;

    my $cond = $self->_build_cond;

    is("$cond", "");
}

sub multi_condition : Test(2) {
    my $self = shift;

    my $cond = $self->_build_cond;

    $cond->cond(id => 2, title => 'hello');

    is($cond->to_string, "(`id` = ? AND `title` = ?)");
    is_deeply($cond->bind, [qw/ 2 hello /]);
}

sub multi_condition_call : Test {
    my $self = shift;

    my $cond = $self->_build_cond;

    $cond->cond([id => 2]);
    $cond->cond(di => 3);

    is($cond->to_string, "(`id` = ? AND `di` = ?)");
}

sub in : Test(2) {
    my $self = shift;

    my $cond = $self->_build_cond;

    $cond->cond([id => [1, 2, 3]]);

    is($cond->to_string, "(`id` IN (?, ?, ?))");
    is_deeply($cond->bind, [qw/ 1 2 3 /]);
}

sub with_prefix : Test(2) {
    my $self = shift;

    my $cond = $self->_build_cond(prefix => 'foo');

    $cond->cond(id => 2, title => 'hello');

    is($cond->to_string, "(`foo`.`id` = ? AND `foo`.`title` = ?)");
    is_deeply($cond->bind, [qw/ 2 hello /]);
}

sub scalarref : Test(2) {
    my $self = shift;

    my $cond = $self->_build_cond;

    $cond->cond([\'foo.id = ?']);
    $cond->bind(2);

    is($cond->to_string, "(foo.id = ?)");
    is_deeply($cond->bind, [2]);
}

sub value_as_scalarref : Test {
    my $self = shift;

    my $cond = $self->_build_cond;

    $cond->cond([password => \"PASSWORD('foo')"]);

    is($cond->to_string, "(`password` = PASSWORD('foo'))");
}

sub null_value : Test {
    my $self = shift;

    my $cond = $self->_build_cond;

    $cond->cond(foo => undef);

    is($cond->to_string, "(`foo` IS NULL)");
}

sub change_logic : Test {
    my $self = shift;

    my $cond = $self->_build_cond;

    $cond->cond(
        -or => [
            'foo.id' => undef,
            -and     => ['foo.title' => 'boo', 'foo.content' => 'bar']
        ]
    );

    is($cond->to_string, "((`foo`.`id` IS NULL OR (`foo`.`title` = ? AND `foo`.`content` = ?)))");
}

sub multi_change_logic : Test {
    my $self = shift;

    my $cond = $self->_build_cond;

    $cond->cond(
        [   -or => [
                a => 1,
                b => 2
            ],
            -or => [
                c => 1,
                d => 2
            ]
        ]
    );

    is($cond->to_string, "((`a` = ? OR `b` = ?) AND (`c` = ? OR `d` = ?))");
}

sub change_default_logic : Test {
    my $self = shift;

    my $cond = $self->_build_cond;

    $cond->logic('OR');
    $cond->cond('foo.id' => 2);

    is($cond->to_string, "(`foo`.`id` = ?)");
}

sub change_operator : Test {
    my $self = shift;

    my $cond = $self->_build_cond;

    $cond->cond(['foo.id' => {'>' => 2}]);

    is($cond->to_string, "(`foo`.`id` > ?)");
}

sub not_create_side_effects : Test(4) {
    my $self = shift;

    my $cond = $self->_build_cond;

    $cond->cond(foo => 'bar');

    is($cond->to_string, "(`foo` = ?)");
    is_deeply($cond->bind, ['bar']);

    is($cond->to_string, "(`foo` = ?)");
    is_deeply($cond->bind, ['bar']);
}

sub _build_cond {
    my $self = shift;

    return ObjectDB::SQL::Condition->new(@_);
}

1;
