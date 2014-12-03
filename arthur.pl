#!/usr/bin/env perl

use warnings;
use strict;

package Avalon::Arthur;
{
    $Avalon::Arthur::VERSION = '0.01';
}

use Bot::BasicBot::Pluggable;
use Config::Simple;

my %cfg;
Config::Simple->import_from('arthur.cfg', \%cfg);

my $bot = Bot::BasicBot::Pluggable->new(
    nick     => $cfg{'irc.nick'},
    ircname  => $cfg{'irc.ircname'},
    server   => $cfg{'irc.server'},
    port     => $cfg{'irc.port'},
    password => $cfg{'irc.password'},
    ssl      => $cfg{'irc.ssl'},
    channels => ($cfg{'irc.channel'}),
    store    => Bot::BasicBot::Pluggable::Store->new(),
);
$bot->{cfg} = \%cfg;

$bot->load("Auth");
$bot->{store_object}->{store}->{Auth}->{password_admin} = $cfg{'admin.password'};
$bot->load("Loader");
$bot->load("Avalon");

$bot->run();
