#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;

use_ok('ObjectDB::SQL::Select');

my $sql = ObjectDB::SQL::Select->new;
$sql->source('table');
$sql->source(
    {   name       => 'table',
        join       => 'left',
        as         => 'table',
        constraint => ['alias.id' => 'table.id']
    }
);
$sql->columns(qw/foo/);
is("$sql", "SELECT `foo` FROM `table`");

$sql = ObjectDB::SQL::Select->new;
$sql->source('table');
$sql->source(
    {   name       => 'table',
        join       => 'left',
        as         => 'alias',
        constraint => ['alias.id' => \'`table`.`id`']
    }
);
$sql->source(
    {   name       => 'table',
        join       => 'left',
        as         => 'alias',
        constraint => ['alias.id' => \'`table`.`id`']
    }
);
$sql->columns(qw/foo/);
is("$sql",
    "SELECT `alias`.`foo` FROM `table` LEFT JOIN `table` AS `alias` ON (`alias`.`id` = `table`.`id`)"
);
