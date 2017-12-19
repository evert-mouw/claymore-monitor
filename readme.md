# claymore-monitor

## About

This is a simple *Bash* script that can be used to monitor a running [Claymore](https://github.com/nanopool/Claymore-Dual-Miner/releases) miner. It makes use of [netcat](http://nc110.sourceforge.net/) and the [jq](https://stedolan.github.io/jq/) JSON parser. For email notifications, you might want to install *s-nail*. It can also handle desktop notifications with `notify-send` and sound notifications using `espeak`. You can also specify an action command to execute if critical values are reached.

Tested on an Arch Linux rig mining Ethereum (ETH).

## Useage

Run with either `show` or `watch` as sole argument.

## Version

- 2017-12-10 initial version by Evert Mouw <post@evert.net>
- 2017-12-19 added notify-send, espeak and action (Evert)
