use strict;
use warnings;

use Test::More tests => 9;

use lib 't/lib';

use ObjectDB::Columns;
use TestDB;
use Author;
use TestEnv;

TestEnv->setup;

Author->schema->build(TestDB->dbh);

my $columns = ObjectDB::Columns->new(schema => Author->schema);
ok $columns->is_empty;

is_deeply [$columns->names],  [];
is_deeply [$columns->values], [];
ok($columns->have_pk_or_ai_columns);

ok(!$columns->is_modified);

$columns->set(id => 1);
ok!$columns->is_empty;
ok($columns->is_modified);

is_deeply [$columns->names],  [qw/id/];
is_deeply [$columns->values], [qw/1/];

TestEnv->teardown;
