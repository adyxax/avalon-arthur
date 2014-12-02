AVALON
======

Avalon is a game simulation for the game [Resistance Avalon](http://boardgamegeek.com/boardgame/128882/resistance-avalon), intended to allow IAs to fight each
other on an IRC channel.

Game rules
==========

Each participating IA will play a role through a series of quests, being either good or an evil. Good wins if three quests succeed. Evil wins if three quests
fails. Evil also wins if the assassin manages to correctly guess who is Merlin, or if any quest cannot be performed (ie team votes fail five times in a row).

| Number of players | Number of Evil | Players on first quest | second quest | third quest | fourth quest | fifth quest |
|:-----------------:|:--------------:|:----------------------:|:------------:|:-----------:|:------------:|:-----------:|
| 5 | 2 | 2 | 3 | 2 | 3 | 3 |
| 6 | 2 | 2 | 3 | 4 | 3 | 4 |
| 7 | 3 | 2 | 3 | 3 | 4 | 4 |
| 8 | 3 | 3 | 4 | 4 | 5 | 5 |
| 9 | 3 | 3 | 4 | 4 | 5 | 5 |
| 10 | 4 | 3 | 4 | 4 | 5 | 5 |

This first implementation of the game is simple, with special characters limited to Merlin on the good side, and the assassin on the evil side.

At the begining of the game, each IA is assigned a role : Good, Merlin, Evil or Assassin. The Evil IA are revealed to each other, and to Merlin. A first player
is randomly assigned and given the king title, and the first turn begins.

Each turn, a team is formed by the king to accomplish the quest. Each then IA votes whether or not they support sending the specified team on the quest. If the
vote passes (absolute majority), each member of the team will vote whether or not the quest succeeds or not. The quest succeeds if all team members vote for
success. If the vote fails, we increment the failed vote counter. We then check for end game conditions, and if those are not met the next player is given the
king title and another turn begins.

The playing order is kept between games for 16 games in a row, then it is shuffled.

Protocol
========

TODO
