package SchemaTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;
use Test::Fatal;

#sub require_table : Test {
#    is(exception { ObjectDB::Schema->new(class => 'Foo') }, '');
#}

sub require_class : Test {
    like(
        exception { ObjectDB::Schema->new(table => 'foo') },
        qr/class is required when building schema/
    );
}

sub has_class : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    is($schema->class, 'Foo');
}

sub has_table_name : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    is($schema->table, 'foo');
}

sub has_columns : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);

    is_deeply([$schema->columns], [qw/foo bar baz/]);
}

sub add_columns : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);

    $schema->add_column('bbb');

    is_deeply([$schema->columns], [qw/foo bar baz bbb/]);
}

sub has_primary_key : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);
    $schema->primary_key('foo');

    is_deeply([$schema->primary_key], [qw/foo/]);
}

sub die_when_setting_primary_key_on_unknown_column : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);

    like(
        exception { $schema->primary_key('unknown') },
        qr/Unknown column 'unknown' in class Foo/
    );
}

sub has_unique_key : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);
    $schema->unique_keys('foo');

    is_deeply($schema->unique_keys, [[qw/foo/]]);
}

sub die_when_setting_unique_key_on_unknown_column : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);

    like(
        exception { $schema->unique_keys('unknown') },
        qr/Unknown column 'unknown' in class Foo/
    );
}

sub has_auto_increment_key : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);
    $schema->auto_increment('foo');

    is_deeply($schema->auto_increment, 'foo');
}

sub die_when_setting_auto_increment_on_unknown_column : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);

    like(
        exception { $schema->auto_increment('unknown') },
        qr/Unknown column 'unknown' in class Foo/
    );
}

sub return_regular_columns : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);
    $schema->primary_key('foo');
    $schema->unique_keys('bar');

    is_deeply([$schema->regular_columns], ['bar', 'baz']);
}

sub check_is_column : Test(2) {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);

    ok($schema->is_column('foo'));
    ok(!$schema->is_column('unknown'));
}

sub has_relationships : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);
    $schema->primary_key('foo');
    $schema->unique_keys('bar');

    $schema->belongs_to('foo');

    ok($schema->relationship('foo'));
}

sub add_relationships : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);

    $schema->belongs_to('foo');

    $schema->add_relationships(bar => {type => 'many to one'});

    is_deeply([sort $schema->parent_relationships], [qw/bar foo/]);
}

sub has_child_relatioships : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);

    $schema->has_many('foo');

    is_deeply([$schema->child_relationships], ['foo']);
}

sub has_parent_relationships : Test {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->columns(qw/foo bar baz/);

    $schema->belongs_to('foo');

    is_deeply([$schema->parent_relationships], ['foo']);
}

sub check_is_relationship : Test(2) {
    my $self = shift;

    my $schema = $self->_build_schema;

    $schema->belongs_to('foo');

    ok($schema->is_relationship('foo'));
    ok(!$schema->is_relationship('unknown'));
}

sub inherit_table : Test {
    my $self = shift;

    {
        package Parent;
        use base 'ObjectDB';
        __PACKAGE__->schema('parents');
    }

    {
        package Child;
        use base 'Parent';
        __PACKAGE__->schema;
    }

    my $schema = Child->schema;

    is($schema->table, 'parents');
}

sub inherit_columns : Test {
    my $self = shift;

    {
        package Parent;
        use base 'ObjectDB';
        __PACKAGE__->schema('parents')->columns(qw/foo/);
    }

    {
        package Child;
        use base 'Parent';
        __PACKAGE__->schema->add_column(qw/bar/);
    }

    my $schema = Child->schema;

    is_deeply([$schema->columns], [qw/foo bar/]);
}

sub _build_schema {
    my $self = shift;

    return ObjectDB::Schema->new(table => 'foo', class => 'Foo', @_);
}

1;
