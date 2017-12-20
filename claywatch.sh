#!/bin/bash

# Use the Claymore miner API to get basic information and notify
# the user using CLI (echo), GUI( notify-send) and sound (espeak).
# Also send emais to the owner (I recommend s-nail and msmtp.)
# Furthermore initiate a reboot action if the miner has failed.
# Suggestion: add this script to cron for automated monitoring.

# ONLY tested with 4 GPUs mining ETH only using Arch Linux
# Evert Mouw <post@evert.net>
# 2017-12-10, 2017-12-19

# GNU netcat has broken timeout (wait)
# so use OpenBSD netcat instead!
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=97583
# pacman -R gnu-netcat
# pacman -S openbsd-netcat

EMAIL="post@evert.net"
WARNMINHASH=16
WARNMINGPU=4
SERVER="localhost"
REBOOTACTION="/opt/claymore/reboot.sh"
SPEAK="yes"

#-----------------------------------------------------

set -euo pipefail
argument=${1:-}

if [[ $(whoami) != "root" ]]
then
	echo "I need root (sudo) rights."
	exit 1
fi

# define variables
declare -a RESULT #array

function main {
	depending
	portchecking
	getting
	testing
	processing
	watchdogging
	showing
	#case $argument in
	#	show) showing ;;
	#	watch) watchdogging ;;
	#	*) echo "Invoke with { show | watch } as argument." ;;
	#esac
}

function depending {
	DEPENDENCIES="netcat jq mail"
	for DEP in $DEPENDENCIES
	do
		if ! which $DEP > /dev/null
		then
			echo "I need $DEP installed!"
			exit 1
		fi
	done
}

function portchecking {
	if ! netcat -z $SERVER 3333
	then
		local MSG="Could not connect to $SERVER on port 3333"
		echo "$MSG"
		echo "$MSG" | mail -s "#~ Miner $(hostname) DOWN" $EMAIL
		if which notify-send > /dev/null
		then
			notify-send --icon=warn "Miner not running" "$MSG"
		fi
		exit 1
	fi
}

function getting {
	# get the json encoded info using the claymore api
	IFS=$'\n'
	RESULT=($(echo '{"id":0,"jsonrpc":"2.0","method":"miner_getstat1"}' | netcat -w 2 $SERVER 3333 | jq '{result}'))
	if [[ ${RESULT[0]} == "" ]]
	then
		DEAD="NO RESPONSE: port open but no answer. The miner is probably dead."
		helper_showandmail_unresponsive $DEAD
		exit 1
	fi
}

function testing {
	echo "Variable info:"
	declare -p RESULT

	i=0
	echo "All elements:"
	for e in ${RESULT[@]}
	do
		echo "[$i] $e"
		i=$((i+1))
	done

	echo "3 - uptime in minutes"
	echo "4 - totals for ETH: hashrate + shares + rejected shares"
	echo "5 - hashrate per gpu"
	echo "8 - temperature and fan speed(%) pairs for all GPUs."
	echo "9 - current mining pool"
}

function processing {
	UPTIME=$(echo ${RESULT[3]} | egrep -o '[0-9]+')

	LINE4=$(echo ${RESULT[4]} | egrep -o '[0-9]+')
	TOTALHASH=$(echo $LINE4 | cut -d' ' -f1)
	TOTALHASH=$((TOTALHASH/1000))
	TOTALSHARES=$(echo $LINE4 | cut -d' ' -f2)
	TOTALREJECT=$(echo $LINE4 | cut -d' ' -f3)

	LINE5=$(echo ${RESULT[5]} | egrep -o '[0-9]+')
	LINE8=$(echo ${RESULT[8]} | egrep -o '[0-9]+')
	i=0
	for gpu in $LINE5
	do
		GPU_HASH[$i]=$((gpu/1000))
		j=$((i+1))
		FIELDSTART=$((1+(j-1)*2))
		GPU_TEMP[$i]=$(echo $LINE8 | cut -d' ' -f$FIELDSTART)
		GPU_FANP[$i]=$(echo $LINE8 | cut -d' ' -f$((FIELDSTART+1)))
		i=$((i+1))
	done
	GPUCOUNT=$i

	#LINE9=$(echo ${RESULT[9]} | egrep -o '\".+\"' | tr -d \")
	LINE9=$(echo ${RESULT[9]} | cut -d\" -f2)
	POOL="$LINE9"
}

function showing {
	SUMMARY="Mining Summary"
	SUMMARY="$SUMMARY\nTotal hashrate: $TOTALHASH MHz"
	SUMMARY="$SUMMARY\nNumber of GPUs: $GPUCOUNT"
	SUMMARY="$SUMMARY\nUptime: $UPTIME minutes"
	SUMMARY="$SUMMARY\nMining pool: $POOL"
	SUMMARY="$SUMMARY\nTotal shares accepted: $TOTALSHARES"
	SUMMARY="$SUMMARY\nTotal shares rejected: $TOTALREJECT"
	
	echo -e $SUMMARY
	i=0
	NOTIFICATION="gpu\thash\ttemp\tfan"
	while [ $i -lt $GPUCOUNT ]
	do
		echo "GPU $i: ${GPU_HASH[$i]} MHz, ${GPU_TEMP[$i]} degrees C, fan at ${GPU_FANP[$i]} %"
		NOTIFICATION="$NOTIFICATION\n$i\t${GPU_HASH[$i]} MHz\t${GPU_TEMP[$i]} C\t\t${GPU_FANP[$i]} %"
		i=$((i+1))
	done
	if which notify-send > /dev/null
	then
		notify-send --icon=info "Now mining at $TOTALHASH MHz" "\n$NOTIFICATION\n\n$SUMMARY"
	fi
	if [ "$SPEAK" == "yes" ]
	then
		espeak "Informational. Mining at $TOTALHASH megahertz. Counting $GPUCOUNT cards. All normal." 2>/dev/null
	fi
}

function helper_showandmail_slow {
	#echo "$1"
	echo "$1" | mail -s "#! Miner $(hostname) slow" $EMAIL
	if which notify-send > /dev/null
	then
		notify-send --icon=warn "Slow mining" "$1"
	fi
	if [ "$SPEAK" == "yes" ]
	then
		espeak "Warning: mining with low hashrate. $1" 2>/dev/null
	fi
}

function helper_showandmail_gpucount {
	#echo "$1"
	echo "$1" | mail -s "#! Miner $(hostname) GPU missing" $EMAIL
	if which notify-send > /dev/null
	then
		notify-send --icon=warn "Mining GPU error" "$1"
	fi
	if [ "$SPEAK" == "yes" ]
	then
		espeak "Critical warning: GPU missing from miner. $1" 2>/dev/null
	fi
}

function helper_showandmail_unresponsive {
	echo "$1"
	echo "$1" | mail -s "#! Miner $(hostname) unresponsive" $EMAIL
	if which notify-send > /dev/null
	then
		notify-send --icon=warn "Miner is dead" "$1"
	fi
	if [ "$SPEAK" == "yes" ]
	then
		espeak "Critical error: $1" 2>/dev/null
	fi
	$REBOOTACTION
}

function watchdogging {
	# only continue if the uptime is long enough
	MINUPTIME=$((GPUCOUNT+2))
	if [[ $UPTIME -lt $MINUPTIME ]]
	then
		return
	fi
	# check the hashrate of each individual GPU
	i=0
	while [ $i -lt $GPUCOUNT ]
	do
		if [ ${GPU_HASH[$i]} -lt $WARNMINHASH ]
		then
			helper_showandmail_slow "GPU $i hashrate is only ${GPU_HASH[$i]} MHz"
		fi
		i=$((i+1))
	done
	# count the total number of GPUs
	if [ $GPUCOUNT -lt $WARNMINGPU ]
	then
		helper_showandmail_gpucount "Only $GPUCOUNT GPUs active, while $WARNMINGPU were expected. Uptime is $UPTIME minutes."
		sleep 1
		$REBOOTACTION
	fi
}

### start running the main loop
main
