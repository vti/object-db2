#!/usr/bin/env perl

use strict;
use warnings;

use inc::Module::Install;

name 'ObjectDB';

version_from 'lib/ObjectDB.pm';
author 'Viacheslav Tykhanovskyi <vti@cpan.org>';
abstract 'Lightweight Object-relational mapper';
license 'artistic_2';
perl_version '5.008007';

requires 'Carp';
requires 'Class::Load';
requires 'DBI';
requires 'DBIx::Connector' => '0.36';
requires 'Scalar::Util';

test_requires 'DBD::SQLite';

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';

no_index directory => 't';

resources
  bugtracker => 'http://github.com/vti/object-db2/issues',
  repository => 'http://github.com/vti/object-db2/',
  license    => 'http://dev.perl.org/licenses/';

auto_install;

WriteAll;
