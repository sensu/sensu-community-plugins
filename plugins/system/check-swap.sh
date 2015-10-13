#!/bin/bash
#
# Evaluate swap memory usage from Linux based systems.
#
# Date: 2007-11-12
# Author: Thomas Borger - ESG
# Date: 2012-04-02
# Modified: Norman Harman - norman.harman@mutualmobile.com
# Date: 2013-03-13
# Modified: Jean-Francois Theroux - jtheroux@lapresse.ca
#
# The swap check is done with following command line:
# vmstat | tail -n1 | awk '{ print $3 }'

# get arguments

# #RED 
while getopts 'w:c:hp' OPT; do
  case $OPT in
    w)  WARN=$OPTARG;;
    c)  CRIT=$OPTARG;;
    h)  hlp="yes";;
    p)  perform="yes";;
    *)  unknown="yes";;
  esac
done

# usage
HELP="
    usage: $0 [ -w value -c value -p -h ]

        -w --> Warning MB < value
        -c --> Critical MB < value
        -p --> print out performance data
        -h --> print this help screen
"

if [ "$hlp" = "yes" ]; then
  echo "$HELP"
  exit 0
fi

WARN=${WARN:=0}
CRIT=${CRIT:=0}

USED_SWAP=$((`vmstat | tail -n1 | awk '{ print $3 }'` / 1024 ))

if [ "$USED_SWAP" = "" ]; then
  echo "SWAP UNKNOWN -"
  exit 3
fi

if [ "$perform" = "yes" ]; then
  output="used swap memory: $USED_SWAP MB | used swap memory="$USED_SWAP"MB;$WARN;$CRIT;0"
else
  output="used swap memory: $USED_SWAP MB"
fi

if (( $USED_SWAP >= $CRIT )); then
  echo "SWAP CRITICAL - $output"
  exit 2
elif (( $USED_SWAP >= $WARN )); then
  echo "SWAP WARNING - $output"
  exit 1
else
  echo "SWAP OK - $output"
  exit 0
fi
