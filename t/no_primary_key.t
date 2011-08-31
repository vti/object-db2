#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;

use lib 't/lib';

use TestEnv;

use Message;

TestEnv->setup;

my $message = Message->new;

ok(!eval { $message->id('test') }, 'id() fails');

like($@, qr/no primary key defined/i, 'error message is right');

ok $message->set_columns(
    sender   => 'sender1',
    receiver => 'receiver1',
    message  => 'message1'
)->create, 'created message';

my @messages = $message->find(where => [sender => 'sender1']);

is $messages[0]->column('message'), 'message1', 'message found';
