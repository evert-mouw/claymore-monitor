#!/bin/bash

# give me stats
# use with cron (cronie) with
# ln -s THISFILE /etc/cron.daily/ethstats
# Evert Mouw <post@evert.net>
# 2017-12-10

DWARF=$(curl -s "http://dwarfpool.com/eth/api?wallet=0x20843145b36b5e7415c4243ee4cd23aea4df750d&email=post@evert.net")

ETHEUR="https://www.coingecko.com/en/price_charts/ethereum/eur"
BALANCE="https://etherchain.org/account/0x20843145b36b5e7415c4243ee4cd23aea4df750d"

echo -e "$DWARF\n\n$ETHEUR\n\n$BALANCE" | mail -s "#~ dwarfpool" post@evert.net

