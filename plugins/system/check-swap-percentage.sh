#!/bin/bash
#
# Checks SWAP usage as a % of the total swap
#
# Date: 05/12/13
# Author: Nick Barrett - EDITD
# License: MIT
#
# Usage: check-swap-percentage.sh -w warn_percent -c critical_percent
# Uses free (Linux-only) & bc

# #RED
# input options
while getopts ':w:c:' OPT; do
  case $OPT in
    w)  WARN=$OPTARG;;
    c)  CRIT=$OPTARG;;
  esac
done

WARN=${WARN:=100}
CRIT=${CRIT:=100}


# get swap details
USED=`free -m | grep 'Swap:' | awk '{ print $3 }'`
TOTAL=`free -m | grep 'Swap:' | awk '{ print $2 }'`

if [[ $TOTAL -eq 0 ]] ; then
  echo "There is no SWAP on this machine"
  exit 0
else
  PERCENT=`echo "scale=3;$USED/$TOTAL*100" | bc -l | awk '{printf "%f", $0}'`

  OUTPUT="Swap usage: $PERCENT%, $USED/$TOTAL"

  if [ "$(echo "$PERCENT >= $CRIT" | bc)" -eq 1 ] ; then
    echo "SWAP CRITICAL - $OUTPUT"
    exit 2
  elif [ "$(echo "$PERCENT >= $WARN" | bc)" -eq 1 ] ; then
    echo "SWAP WARNING - $OUTPUT"
    exit 1
  else
    echo "SWAP OK - $OUTPUT"
    exit 0
  fi
fi
