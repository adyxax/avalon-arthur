package Bot::BasicBot::Pluggable::Module::Avalon;
{
    $Avalon::Arthur::VERSION = '0.07';
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

sub check_endgame_and_proceed {
    my $self = shift;
    my $av = $self->{avalon};

    given ($av->{gamephase}) {
        when (TEAMVOTE) {
            if ($av->{round}->{failed_votes} == 5) {
                $self->evil_wins;
            } else {
                $self->new_king;
            }
        }
    }
}

sub evil_wins {
    my ( $self, $who ) = @_;
    my $av = $self->{avalon};
    my $evil_msg = "WINNERSIDE EVIL $av->{roles}->{ASSASSIN}->[0] " . join(' ', @{$av->{roles}->{EVIL}});
    $self->say( channel => $av->{config}->{'game.channel'}, body => $evil_msg );
    $self->reset_game;
}

sub game_ready {
    my $av = shift->{avalon};
    return ( $av->{gamephase} == GAMESTART and scalar keys $av->{registered} >= 5 );
}

sub kick {
    my ( $self, $who ) = @_;
    my $av = $self->{avalon};
    return unless $who ~~ $av->{registered};
    my $avdb = $self->{avdb};
    my $entry = $who . $av->{registered}->{$who}->{version};
    my $score = $avdb->get('KICKS', $entry);
    $avdb->set('KICKS', $entry, defined $score ? int($score) + 1 : 1);
    $self->say( channel => $av->{config}->{'game.channel'}, body => "UNREGISTERED $who" );
    delete $av->{registered}->{$who};
    $self->reset_game if $who ~~ $av->{players};
}

sub load_avalon_db {
    my $self = shift;
    # This database stores registrations and bans
    $self->{avdb} = Bot::BasicBot::Pluggable::Store::DBI->new(
       dsn   => "dbi:SQLite:dbname=arthur.sqlite",
       table => "arthur",
   );
}

sub new_king {
    my $self = shift;
    my $av = $self->{avalon};
    my ($players, $rules) = $self->rules;
    $av->{king} = ($av->{king} +1) % $players;
    $av->{team} = [];
    $self->say( channel => $av->{config}->{'game.channel'}, body => "KING $av->{players}->[$av->{king}] $rules->[$av->{round}->{id}] $av->{round}->{failed_votes}" );
    $av->{gamephase} = TEAM;
    $av->{lastcall} = 0;
    $self->set_timeout(58);
}

sub reset_game {
    my $self = shift;
    my $av = $self->{avalon};
    $av->{gamephase} = GAMESTART;
    $av->{players} = [];
    $av->{roles} = {
        'MERLIN' => [],
        'ASSASSIN' => [],
        'GOOD' => [],
        'EVIL' => [],
    };
    $av->{king} = 0;
    $av->{team} = [];
    $av->{votes} = {};
    $av->{quests} = { pass => 0, fail => 0 };
    $av->{round} = { id => 1, failed_votes => 0 };
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
    @players = @players[0..9] if scalar @players > 10;
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
            $self->new_king;
        }
        when (TEAM) {
            if ($av->{lastcall}) {
                $self->kick($av->{players}->[$av->{king}]);
            } else {
                $self->say( channel => $av->{config}->{'game.channel'}, body => "RULENOW $av->{players}->[$av->{king}]" );
                $self->set_timeout(2);
                $av->{lastcall} = 1;
            }
        }
        when (TEAMVOTE) {
            foreach (@{$av->{players}}) {
                next if (exists $av->{votes}->{$_});
                if ($av->{lastcall}) {
                    $self->kick($_);
                } else {
                    $self->say( channel => 'msg', who => $_, body => "VOTENOW" );
                }
            }
            unless ($av->{lastcall}) {
                $self->set_timeout(2);
                $av->{lastcall} = 1;
            }
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
        when ("UNREGISTER") {
            return unless $av->{registered}->{$who} or $who ~~ $av->{players};
            delete $av->{registered}->{$who};
            $self->say( channel => $av->{config}->{'game.channel'}, body => "UNREGISTERED $who" );
            if ($av->{gamephase} == GAMESTART or (scalar @args > 0 and $args[0] eq "now" and $who ~~ $av->{players})) {
                $self->reset_game;
            }
        }
        when ("UNREGISTERED") {}
        when ("GAMESTART") {}
        when ("ROLE") {}
        when ("EVIL") {}
        when ("KING") {}
        when ("RULENOW") {}
        when ("TEAM") {
            $self->kick($who) unless ($av->{gamephase} == TEAM and $who eq $av->{players}->[$av->{king}]);
            my ($players, $rules) = $self->rules;
            my $team_size = $rules->[$av->{round}->{id}];
            return 'ERR_BAD_ARGUMENTS' if scalar @args != $team_size;
            foreach (@args) {
                if ($_ ~~ $av->{players} and !($_ ~~ $av->{team})) {
                    push $av->{team}, $_;
                } else {
                    $av->{team} = [];
                    return 'ERR_BAD_ARGUMENTS';
                }
            }
            $av->{gamephase} = TEAMVOTE;
            $av->{lastcall} = 0;
            $self->set_timeout(58);
        }
        when ("VOTE") {
            return 'ERR_BAD_ARGUMENTS' unless scalar @args == 1 and $args[0] ~~ [ "yes", "no" ];
            my ($players, $rules) = $self->rules;
            given ($av->{gamephase}) {
                when (TEAMVOTE) {
                    $self->kick($who) unless $who ~~ $av->{players};
                    $av->{votes}->{$who} = $args[0] unless exists $av->{votes}->{$who};
                    if (scalar keys $av->{votes} == $players) {
                        my $score = 0;
                        foreach (keys $av->{votes}) {
                            $score++ if $av->{votes}->{$_} eq "yes";
                        }
                        $av->{votes} = {};
                        if ($score > $players / 2) {
                            $av->{round}->{failed_votes} = 0;
                            $av->{votes} = {};
                            $av->{gamephase} = QUESTVOTE;
                            $av->{lastcall} = 0;
                            $self->set_timeout(58);
                            $self->say( channel => $av->{config}->{'game.channel'}, body => "VOTERESULT PASS $score" );
                        } else {
                            $self->say( channel => $av->{config}->{'game.channel'}, body => "VOTERESULT FAIL $score" );
                            $av->{round}->{failed_votes}++;
                            $self->check_endgame_and_proceed;
                        }
                    }
                }
            }
        }
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
