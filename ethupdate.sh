#!/bin/bash

# give me stats
# use with cron (cronie) with
# ln -s THISFILE /etc/cron.daily/ethstats
# Evert Mouw <post@evert.net>
# 2017-12-10, 2017-12-19

EMAIL="yourname@domain.tld"
WALLET="0x............"

DWARF=$(curl -s "http://dwarfpool.com/eth/api?wallet=$WALLET&email=$EMAIL")

ETHEUR="https://www.coingecko.com/en/price_charts/ethereum/eur"
BALANCE="https://etherchain.org/account/$WALLET"

echo -e "$DWARF\n\n$ETHEUR\n\n$BALANCE" | mail -s "#~ dwarfpool" $EMAIL
