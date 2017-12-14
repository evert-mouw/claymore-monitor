#!/bin/bash

# use the Claymore miner API to get basic information
# ONLY tested with 3 GPUs mining ETH only
# Evert Mouw <post@evert.net>
# 2017-12-10

# suggestion: add $0 watch to hourly cron
# (no symlink; needs "watch" argument)

EMAIL="post@evert.net"
WARNMINHASH=16
WARNMINGPU=3
SERVER="localhost"

#-----------------------------------------------------

set -euo pipefail
argument=${1:-}

# define variables
declare -a RESULT #array

function main {
	depending
	portchecking
	getting
	#testing
	processing
	case $argument in
		show) showing
			;;
		watch) watchdogging
			;;
		*) echo "Invoke with { show | watch } as argument."
			;;
	esac
}

function depending {
	DEPENDENCIES="netcat jq"
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
		exit 1
	fi
}

function getting {
	# get the json encoded info using the claymore api
	IFS=$'\n'
	RESULT=($(echo '{"id":0,"jsonrpc":"2.0","method":"miner_getstat1"}' | netcat $SERVER 3333 | jq '{result}'))
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

	echo "4 - totals for ETH: hashrate + shares + rejected shares"
	echo "5 - hashrate per gpu"
	echo "8 - temperature and fan speed(%) pairs for all GPUs."
	echo "9 - current mining pool"
}

function processing {
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

	

	LINE9=$(echo ${RESULT[9]} | egrep -o '\".+\"')
	POOL="$LINE9"
}

function showing {
	echo "Total hashrate: $TOTALHASH MHz"
	echo "Mining pool: $POOL"
	echo "Total shares accepted: $TOTALSHARES"
	echo "Total shares rejected: $TOTALREJECT"
	echo "Number of GPUs: $GPUCOUNT"
	i=0
	while [ $i -lt $GPUCOUNT ]
	do
		echo "GPU $i: ${GPU_HASH[$i]} MHz, ${GPU_TEMP[$i]} degrees C, fan at ${GPU_FANP[$i]}%"
		i=$((i+1))
	done
}

function helper_showandmail_slow {
	#echo "$1"
	echo "$1" | mail -s "#! Miner $(hostname) slow" $EMAIL
}

function helper_showandmail_gpucount {
	#echo "$1"
	echo "$1" | mail -s "#! Miner $(hostname) GPU missing" $EMAIL
}

function watchdogging {
	i=0
	while [ $i -lt $GPUCOUNT ]
	do
		if [ ${GPU_HASH[$i]} -lt $WARNMINHASH ]
		then
			helper_showandmail_slow "GPU $i hashrate is only ${GPU_HASH[$i]} MHz"
		fi
		i=$((i+1))
	done
	if [ $GPUCOUNT -lt $WARNMINGPU ]
	then
		helper_showandmail_gpucount "Only $GPUCOUNT GPUs active, while $WARNMINGPU were expected."
	fi
}

### start running the main loop
main
