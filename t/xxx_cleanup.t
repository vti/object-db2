#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

plan tests => 1;

use lib 't/lib';

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
}
