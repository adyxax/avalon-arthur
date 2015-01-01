AVALON
======

Avalon is a game simulation for the game [Resistance Avalon](http://boardgamegeek.com/boardgame/128882/resistance-avalon), intended to allow AIs to fight each
other on an IRC channel.

Game rules
==========

Each participating AI will play a role through a series of quests, being either good or evil. Good wins if three quests succeed. Evil wins if three quests
fail. Evil also wins if the assassin manages to correctly guess who Merlin is, or if any quest cannot be performed (ie team votes fail five times in a row).

| Number of players | Number of Evil | Players on first quest | second quest | third quest | fourth quest | fifth quest |
|:-----------------:|:--------------:|:----------------------:|:------------:|:-----------:|:------------:|:-----------:|
| 5 | 2 | 2 | 3 | 2 | 3 | 3 |
| 6 | 2 | 2 | 3 | 4 | 3 | 4 |
| 7 | 3 | 2 | 3 | 3 | 4+ | 4 |
| 8 | 3 | 3 | 4 | 4 | 5+ | 5 |
| 9 | 3 | 3 | 4 | 4 | 5+ | 5 |
| 10 | 4 | 3 | 4 | 4 | 5+ | 5 |

This first implementation of the game is simple, with special characters limited to Merlin on the good side, and the assassin on the evil side.

At the begining of the game, each AI is assigned a role : Good, Merlin, Evil or Assassin. The Evil AI are revealed to each other, and to Merlin. A first player
is randomly assigned and given the king title, and the first turn begins.

On each turn, a team is formed by the king to accomplish the quest. Then each AI votes whether or not they support sending the specified team on the quest. If the
vote passes (absolute majority), each member of the team will vote whether or not the quest succeeds. The quest succeeds if all team members vote for
success, except for the fourth quest at 7 or more players succeeds if all or all but one team members vote for success. If the vote fails, we increment the failed vote counter. We check then for end game conditions, and if those are not met, the next player is given the
king title and another turn begins.

The playing order is kept between games for 16 games in a row, then it is shuffled.

When at least 5 bots are registered for a game, the game starts 10 seconds later. Other bots can still register or unregister, each event resetting the 10
seconds timer.

When a vote begins, each client has 15 seconds to vote.

Protocol
========

The following describes the avalon protocol version 0.1.

Message Format
--------------

Each message is composed of a command in caps and a list of parameters separated by spaces.

Messages can be used by clients (IA), the Game Server (called Arthur in the rest of this document), or both.

All messages are to be sent to arthur directly using PRIVMSG and not on the game channel unless specified otherwise.

Messages
--------

### Registration

#### REGISTER *owner* *bot_version* *protocol_version*
REGISTER message is used by clients to tell Arthur that they want to participate in the next game. The *owner* parameter is the irc nick of the bot's creator, and
will be used for the leaderboards. The *bot_version* is the version of your bot implementation, again for the leaderboards. The *protocol_version* is used to make
sure your bot matches with the current protocol and ruleset for the Avalon Game.

Upon registration, the entire irc identification string is recorded (for example *pbot!~julien@midgard*) to identify your bot. If this doesn't match a previous
registration for this nickname, your registration will be answered by an ERR_NICK_RESERVED message. If your protocol_version mismatches Arthur's, your
registration will be answered by an ERR_PROTOCOL_MISMATCH message. If the couple (nick, *bot_version*) is banned, arthur will answer with ERR_BANNED.

#### REGISTERED [nick]
REGISTERED message is sent by arthur on the #avalon game channel to confirm your registration and announce it to all participants.

#### UNREGISTER [now]
UNREGISTER message is sent by clients to specify their intention not to participate in the next game. The optionnal parameter *now* specifies the game is to
be cancelled. Please be a gentleman and gently let your bot finish the current game and only use the *now* parameter when absolutely needed (irrecoverable error).

#### UNREGISTERED
UNREGISTERED message is sent by arthur to confirm your unregistration. This will also trigger an INFO message on the #avalon game channel.

### Game flow

#### GAMESTART *nick* *nick* ...
GAMESTART message is sent by arthur on the #avalon game channel to mark the start of the game. The parameters of this command are the clients in playing order.

10 seconds after the GAMESTART message is issued, the game will effectively start by sending ROLE and KING messages. If any new REGISTER or UNREGISTER messages
are received during this time lapse and if there are still enough participants for a game, a new GAMESTART message is sent and this timer restarts from 10.

#### ROLE *role* [nick]
ROLE message is sent right after the GAMESTART message to tell each client it's *role* which can be either : GOOD, MERLIN, EVIL, ASSASSIN. The *nick* parameter
is unused in this scope
ROLE message is also sent by arthur at the end of the game on the #avalon game channel.

#### EVIL *nick* *nick*
EVIL message is sent to evil players and MERLIN right after roles have been announced by arthur.

#### KING *nick* *team_size* *failed_votes*
KING message is sent by arthur on the #avalon game channel to signal the new king. *team_size* is the number of teammates the king must designate to go on the
quest. *failed_votes* is the current number of failed votes in a row, after 5 failed votes in a row the EVIL side wins. When the KING message is issued, the client has 60 seconds to designate it's team. Since we are relying on IRC as a message transport, which is known for throttling messages, do not trust that you have exactly 60 seconds to answer : you have a little less depending on the number of players and the IRC server configuration.

#### RULENOW *nick*
RULENOW message is sent by arthur to the king on the #avalon game channel to signal a client it has only 2 seconds remaining to designate it's team. If the
client already sent it's TEAM message, this message must be ignored.

Failure to do so in time results on an UNREGISTERED message from arthur and another game begins with the remaining participants 10 sec later. The kicked client
can re register for the next game, but after 3 failures in a row the client and it's version will be banned from entering the game until it's developper fixes
it's code and increment the version number.

#### TEAM *nick* *nick* ...
TEAM message is sent by the king on the #avalon game channel to advertise to all participants the team it has chosen to go on the quest. When the TEAM message is
receive, a 60 seconds voting window opens for the clients.

#### VOTE *yes|no*
VOTE message is sent by clients to arhur to vote on a quest. Only the first VOTE message on each quest is taken in consideration by arthur, others are ignored.

#### VOTENOW
VOTENOW message is sent by arthur to clients that didn't vote already to signal them that they have only 2 seconds remaining to vote. If the client already voted
this turn, it can ignore this message.

The same failure outcome as for the RULENOW message applies here.

#### VOTERESULT *PASS|FAIL* *yes*
VOTERESULT message is sent on the #avalon game channel by arthur to give the result of the vote. *status* is either PASS or FAIL, *yes* is the number of yes in
the vote. If the vote status is PASS, team members have 60 seconds to send a new vote, for the quest success this time.

If the vote status is FAILED, another turn ends and endgame conditions are evaluated.

#### QUESTRESULT *PASS|FAIL* *yes*
QUESTRESULT message is sent on the #avalon game channel by arthur to give the result of the quest. *status* is either PASS or FAIL, *yes* is the number of yes in
the vote.

### Game ends

#### KILLMERLIN
KILLMERLIN message is sent on the #avalon game channel by arthur to ask the ASSASSIN has 60 seconds to guess who MERLIN isi if the GOOD side win three quests.

#### KILLMERLINNOW
KILLMERLINNOW message is sent by arthur to the assassin that didn't designate MERLIN when there are only 2 seconds remaining.

#### KILL *nick*
KILL message is sent by the ASSASSIN to designate *nick* as MERLIN.

#### WINNERSIDE *GOOD|EVIL* *nick* *nick* ...
WINNERSIDE message is sent by arthur to designate the winner's side at the end of the game. Winning nicks are given as arguments for posterity and glory.

#### INFO *stuff*
INFO messages are sent at various points by arthur to comment on what is happening : a bot misbehaves, etc. Those messages can
be safely ignored and are only provided for additional entertainment.

#### GAMEURL *url*
GAMEURL message is sent by arthur on the #avalon game channel to provide the game transcript.

### Errors

#### ERR_BAD_ARGUMENTS

#### ERR_BAD_DESTINATION

#### ERR_NICK_RESERVED

#### ERR_PROTOCOL_MISMATCH

#### ERR_BANNED

#### ERR_INVALID_TEAM

#### ERR_INVALID_VOTE

#### ERR_VOTE_TIMEOUT

#### ERR_NOT_THE_ASSASSIN

#### ERR_NOT_NOW

#### ERR_JOIN_AVALON_FIRST
