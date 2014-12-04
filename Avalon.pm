package Bot::BasicBot::Pluggable::Module::Avalon;
{
    $Avalon::Arthur::VERSION = '0.02';
};

use strict;
use warnings;
use v5.12;
use experimental qw(autoderef switch);
use Bot::BasicBot::Pluggable::Store::DBI;
use List::Util qw(shuffle);
use POE;
use Time::HiRes qw(time);

use base qw(Bot::BasicBot::Pluggable::Module);

### Game logic ###############################################################
use enum qw(GAMESTART TEAM TEAMVOTE QUESTVOTE ASSASSINGUESS);
use enum qw(NUMBER_OF_EVIL_PLAYERS FIRST_QUEST SECOND_QUEST THIRD_QUEST FOURTH_QUEST FIFTH_QUEST SPECIAL_QUEST_RULE);
my %gamerules = (
    # number of players => ( number of evil, players on first quest, second, third, fourth, fifth, number of fail for fourth quest success )
    5  => [ 2, 2, 3, 2, 3, 3, 0],
    6  => [ 2, 2, 3, 4, 3, 4, 0],
    7  => [ 3, 2, 3, 3, 4, 4, 1],
    8  => [ 3, 3, 4, 4, 5, 5, 1],
    9  => [ 3, 3, 4, 4, 5, 5, 1],
    10 => [ 4, 3, 4, 4, 5, 5, 1],
);

sub load_avalon_db {
    my $self = shift;
    # This database stores registrations and bans
    $self->{avdb} = Bot::BasicBot::Pluggable::Store::DBI->new(
       dsn   => "dbi:SQLite:dbname=arthur.sqlite",
       table => "arthur",
   );
}

sub reset_game {
    my $av = shift->{avalon};
    $av->{gamephase} = GAMESTART;
    $av->{gamesplayed} = 0;
    $av->{timeout} = 0;
    $av->{registered} = {};
    $av->{players} = ();
    $av->{roles} = {
        'MERLIN' => [],
        'ASSASSIN' => [],
        'GOOD' => [],
        'EVIL' => [],
    };
    $av->{king} = 0;
    $av->{votes} = { pass => 0, fail => 0 };
    $av->{quests} = { pass => 0, fail => 0, votes => 0 };
}

sub set_timeout {
    my ( $self, $value) = @_;
    $poe_kernel->alarm( avalon_timeout => time() + $value );
}

sub timeout_occurred {
    my $self = shift;
    $self->say( channel => $self->{avalon}->{config}->{'game.channel'}, body => "timeout" );
}

### IRC methods override ######################################################
sub connected {
    my $self = shift;
    $poe_kernel->state( 'avalon_timeout', $self, 'timeout_occurred' );
}

sub init {
    my $self = shift;
    $self->{avalon} = {};
    $self->{avalon}->{config} = $self->bot->{store_object}->{store}->{cfg}->{cfg};
    $self->load_avalon_db;
    $self->reset_game;
}

sub help {
    return "The avalon game simulator : https://github.com/adyxax/avalon-arthur";
}

sub told {
    my ( $self, $mess ) = @_;
    my $who = $mess->{who};
    my $body = $mess->{body};
    my $ispriv = defined $mess->{address};
    my $av = $self->{avalon};
    my $avdb = $self->{avdb};

    my ( $command, @args ) = split /\s+/, $mess->{body};
    given ($command) {
        when ("REGISTER") {}
        when ("REGISTERED") {}
        when ("UNREGISTER") {}
        when ("UNREGISTERED") {}
        when ("GAMESTART") {}
        when ("ROLE") {}
        when ("EVIL") {}
        when ("KING") {}
        when ("RULENOW") {}
        when ("TEAM") {}
        when ("VOTE") {}
        when ("VOTENOW") {}
        when ("VOTERESULT") {}
        when ("QUESTRESULT") {}
        when ("KILLMERLIN") {}
        when ("KILLMERLINNOW") {}
        when ("KILL") {}
        when ("WINNERSIDE") {}
        when ("INFO") {}
        when ("GAMEURL") {}
        when ("ERR_BAD_ARGUMENTS") {}
        when ("ERR_BAD_DESTINATION") {}
        when ("ERR_NICK_RESERVED") {}
        when ("ERR_PROTOCOL_MISMATCH") {}
        when ("ERR_BANNED") {}
        when ("ERR_INVALID_TEAM") {}
        when ("ERR_INVALID_VOTE") {}
        when ("ERR_VOTE_TIMEOUT") {}
        when ("ERR_NOT_THE_ASSASSIN") {}
        when ("ERR_NOT_NOW") {}
        when ("ERR_JOIN_AVALON_FIRST") {}
        default {}
    }
}

1;
