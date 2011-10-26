package UtilsTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;

use ObjectDB::SQL::Utils qw(escape prepare_column);

sub escape_column : Test {
    my $self = shift;

    is(escape('foo'), '`foo`');
}

sub escape_escaped_symbols : Test {
    my $self = shift;

    is(escape('fo`o'), '`fo\`o`');
}

sub escape_column_with_specified_quote_symbol : Test {
    my $self = shift;

    is(escape('foo', '#'), '#foo#');
}

sub prepare_column_escape : Test {
    my $self = shift;

    is(prepare_column('foo'), '`foo`');
}

sub prepare_column_escape_with_specified_quote_symbol : Test {
    my $self = shift;

    is(prepare_column('foo', '', '#'), '#foo#');
}

sub prepare_prefixed_column : Test {
    my $self = shift;

    is(prepare_column('foo.bar'), '`foo`.`bar`');
}

sub prepare_with_prefix : Test {
    my $self = shift;

    is(prepare_column('foo', 'bar'), '`bar`.`foo`');
}

sub prepare_with_prefix_and_specified_quote_symbol : Test {
    my $self = shift;

    is(prepare_column('foo', 'bar', '#'), '#bar#.#foo#');
}

sub prepare_with_prefix_already_prefixed_column : Test {
    my $self = shift;

    is(prepare_column('foo.bar', 'baz'), '`foo`.`bar`');
}

1;
