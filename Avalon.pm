package Bot::BasicBot::Pluggable::Module::Avalon;
{
    $Avalon::Arthur::VERSION = '0.05';
};

use strict;
use warnings;
use v5.12;
use experimental qw(autoderef switch);
use Bot::BasicBot::Pluggable::Store::DBI;
use List::Util qw(shuffle);
use Math::Random::Secure qw(rand);
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

sub game_ready {
    my $av = shift->{avalon};
    return ( $av->{gamephase} == GAMESTART and scalar keys $av->{registered} >= 5 );
}

sub load_avalon_db {
    my $self = shift;
    # This database stores registrations and bans
    $self->{avdb} = Bot::BasicBot::Pluggable::Store::DBI->new(
       dsn   => "dbi:SQLite:dbname=arthur.sqlite",
       table => "arthur",
   );
}

sub reset_game {
    my $self = shift;
    my $av = $self->{avalon};
    $av->{gamephase} = GAMESTART;
    $av->{timeout} = 0;
    $av->{players} = ();
    $av->{roles} = {
        'MERLIN' => [],
        'ASSASSIN' => [],
        'GOOD' => [],
        'EVIL' => [],
    };
    $av->{king} = 0;
    $av->{votes} = { pass => 0, fail => 0 };
    $av->{quests} = { pass => 0, fail => 0 };
    $av->{round} = { id => 0, failed_votes => 0 };
    $av->{lastcall} = 0;
    $self->start_game if $self->game_ready;
}

sub rules {
    my $av = shift->{avalon};
    my $players = scalar keys $av->{players};
    return ($players, $gamerules{$players});
}

sub set_timeout {
    my ( $self, $value) = @_;
    $poe_kernel->alarm( avalon_timeout => time() + $value );
}

sub start_game {
    my $self = shift;
    my $av = $self->{avalon};
    my @players = shuffle keys $av->{registered};
    $av->{players} = \@players;
    $self->say( channel => $av->{config}->{'game.channel'}, body => "GAMESTART " . join(' ', @players) );
    $self->set_timeout(10);
}

sub timeout_occurred {
    my $self = shift;
    my $av = $self->{avalon};
    given ($av->{gamephase}) {
        when (GAMESTART) {
            return unless $self->game_ready;
            # First we prepare the characters pool
            my ($players, $rules) = $self->rules;
            my $evils = $rules->[NUMBER_OF_EVIL_PLAYERS];
            my @characters = ( 'MERLIN', 'ASSASSIN');
            for (my $i = 1; $i < $evils; $i++) { push @characters, ( 'EVIL' ); }
            for (my $i = $evils + 1; $i < $players; $i++) { push @characters, ( 'GOOD' ); }
            my @shuffled = shuffle @characters;
            # Then we assign roles
            for (my $i = 0; $i < $players; $i++) {
                my $role = pop @shuffled;
                push $av->{roles}->{$role}, $av->{players}->[$i];
                $self->say( channel => 'msg', who => $av->{players}->[$i], body => "ROLE $role");
            }
            # Now we give special information to special characters
            my $evil_msg = "EVIL $av->{roles}->{ASSASSIN}->[0] " . join(' ', @{$av->{roles}->{EVIL}});
            $self->say( channel => 'msg', who => $av->{roles}->{MERLIN}->[0], body => $evil_msg );
            $self->say( channel => 'msg', who => $av->{roles}->{ASSASSIN}->[0], body => $evil_msg );
            $self->say( channel => 'msg', who => $_, body => $evil_msg ) foreach (@{$av->{roles}->{EVIL}});
            # Finally we designate the first king
            $av->{king} = rand($players);
            $self->say( channel => $av->{config}->{'game.channel'}, body => "KING $av->{players}->[$av->{king}] $rules->[$av->{round}->{id} + 1] $av->{round}->{failed_votes}" );
            $av->{gamephase} = TEAM;
        }
        default {
            $self->say( channel => $av->{config}->{'game.channel'}, body => "timeout" );
        }
    }
}

### IRC methods override ######################################################
sub connected {
    my $self = shift;
    $poe_kernel->state( 'avalon_timeout', $self, 'timeout_occurred' );
}

sub init {
    my $self = shift;
    my $av = $self->{avalon} = {};
    $self->load_avalon_db;
    $av->{config} = $self->bot->{store_object}->{store}->{cfg}->{cfg};
    $av->{gamesplayed} = 0;
    $av->{registered} = {};
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
        when ("REGISTER") {
            return 'ERR_BAD_ARGUMENTS' if scalar @args != 3;
            my ( $owner, $bot_version, $protocol_version ) = @args;
            return 'ERR_PROTOCOL_MISMATCH' if $protocol_version ne $Avalon::Arthur::VERSION;
            my $record = $avdb->get('REGISTRATIONS', $who);
            if ($record) {
                return 'ERR_NICK_RESERVED' if $record ne $mess->{raw_nick};
                return 'ERR_BANNED' if $avdb->get('KICKS', $who . $bot_version) and int($avdb->get('KICKS', $who . $bot_version)) >= 3;
            } else {
                $avdb->set('REGISTRATIONS', $who, $mess->{raw_nick});
            }
            $av->{registered}->{$who} = { owner => $owner, version => $bot_version };
            $self->say( channel => $av->{config}->{'game.channel'}, body => "REGISTERED $who" );
            $self->start_game if $self->game_ready;
        }
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
