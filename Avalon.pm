package Bot::BasicBot::Pluggable::Module::Avalon;
{
    $Avalon::Arthur::VERSION = '0.02';
};

use strict;
use warnings;
use v5.12;
use experimental qw(switch);
use POE;
use Time::HiRes qw(time);

use base qw(Bot::BasicBot::Pluggable::Module);

### Game logic ###############################################################
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
}

sub help {
    return "The avalon game simulator : https://github.com/adyxax/avalon-arthur";
}

sub told {
    my ( $self, $mess ) = @_;
    my $who = $mess->{who};
    my $body = $mess->{body};
    my $ispriv = defined $mess->{address};

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
