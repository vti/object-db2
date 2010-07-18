#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use lib 't/lib';

use TestDB;

if (TestDB->db eq 'sqlite') {
    eval "use DBD::SQLite";
    plan skip_all => "DBD::SQLite is required for running this test" if $@;
}
elsif (TestDB->db eq 'mysql') {
    eval "use DBD::mysql";
    plan skip_all => "DBD::mysql is required for running this test" if $@;
}

plan tests => 1;

use FindBin;
use TestDB;

my $conn = TestDB->conn;
ok($conn);

my $db = TestDB->db;

open(my $file, "< $FindBin::Bin/schema/$db.sql") or die $!;

my $schema = do { local $/; <$file> };

my @sql = split(/\s*;\s*/, $schema);

foreach my $sql (@sql) {
    next unless $sql;

    my ($table) = ($sql =~ m/CREATE\s+TABLE `(.*?)`/i);
    $conn->run(sub { $_->do("DROP TABLE IF EXISTS `$table`") }) if $table;
    $conn->run(sub { $_->do($sql) });
}
