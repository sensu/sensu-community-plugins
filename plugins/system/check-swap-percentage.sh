#!/bin/bash
#
# Checks SWAP usage as a % of the total swap
#
# Date: 05/12/13
# Author: Nick Barrett - EDITD
# License: MIT
#
# Usage: check-swap-percentage.sh -w warn_percent -c critical_percent

typeset -i TOTAL
typeset -i FREE
typeset -i USED
typeset -i PERCENT

# #RED
# input options
while getopts ':w:c:' OPT; do
  case $OPT in
    w)  WARN=$OPTARG;;
    c)  CRIT=$OPTARG;;
  esac
done

WARN=${WARN:=101}
CRIT=${CRIT:=101}

# get swap details
FREE=$(grep SwapFree /proc/meminfo 2>/dev/null | awk '{ print $2 }')
TOTAL=$(grep SwapTotal /proc/meminfo 2>/dev/null | awk '{ print $2 }')

if [[ $TOTAL -eq 0 ]] ; then
  echo "There is no SWAP on this machine"
  exit 0
else
  USED=$(( $TOTAL-$FREE ))
  PERCENT=$(( $USED*100/$TOTAL ))

  OUTPUT="Swap usage: $PERCENT%, "$(($USED/1024))/$(($TOTAL/1024))

  if (( $PERCENT >= $CRIT )); then
    echo "SWAP CRITICAL - $OUTPUT"
    exit 2
  elif (( $PERCENT >= $WARN )); then
    echo "SWAP WARNING - $OUTPUT"
    exit 1
  else
    echo "SWAP OK - $OUTPUT"
    exit 0
  fi
fi
