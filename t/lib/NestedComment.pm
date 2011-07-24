package NestedComment;

use strict;
use warnings;

use base 'TestDB';

__PACKAGE__->schema('nested_comments')
  ->belongs_to(
    parent => {foreign_class => 'NestedComment', map => {parent_id => 'id'}})
  ->has_many(ansestors =>
      {foreign_class => 'NestedComment', map => {id => 'parent_id'}})
  ->proxy(master => {column => 'master_type'});

sub create {
    my $self = shift;
    my $class = ref($self);

    $self->set_columns(@_);

    my $rgt           = 1;
    my $level         = 0;
    my $comment_count = 0;

    my $conn = $self->conn;

    if ($self->column('parent_id')) {
        my $parent = $self->find_related('parent');

        if ($parent) {
            $self->column(master_id   => $parent->column('master_id'));
            $self->column(master_type => $parent->column('master_type'));

            $level = $parent->column('level') + 1;

            $rgt = $parent->column('lft');
        }
    }

    $comment_count = $class->new(conn => $conn)->count(
        master_type => $self->column('master_type'),
        master_id   => $self->column('master_id')
    );

    if ($comment_count) {
        my $left = $class->new(conn => $conn)->find(
            where => [
                master_id   => $self->column('master_id'),
                master_type => $self->column('master_type'),
                parent_id   => $self->column('parent_id')
            ],
            order_by => 'addtime DESC, id DESC',
            single   => 1
        );

        $rgt = $left->column('rgt') if $left;

        $class->new(conn => $conn)->update(
            set   => [rgt => \'rgt + 2'],
            where => [rgt => {'>' => $rgt}]
        );

        $class->new(conn => $conn)->update(
            set   => [lft => \'lft + 2'],
            where => [lft => {'>' => $rgt}]
        );
    }

    $self->column(lft   => $rgt + 1);
    $self->column(rgt   => $rgt + 2);
    $self->column(level => $level);

    $self->column(addtime => time) unless $self->column('addtime');

    return $self->SUPER::create;
}

1;
