use strict;
use warnings;

use Test::More tests => 2;

use lib 't/lib';

use TestEnv;

use Message;
use Identificator;

TestEnv->setup;

my $alice = Identificator->new(columns => {name => 'Alice'})->create;
my $bob   = Identificator->new(columns => {name => 'Bob'})->create;

my $message = Message->new(
    columns => {
        sender_id    => $alice->id,
        recipient_id => $bob->id,
        message      => 'Hi!'
    }
)->create;

my @messages = Message->new->find(
    with  => [qw/sender recipient/],
    where => ['sender.name' => 'Alice']
);
$message = $messages[0];
is $message->sender->name,    'Alice';
is $message->recipient->name, 'Bob';

TestEnv->teardown;
