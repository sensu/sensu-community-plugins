#!/bin/bash
#
# Evaluate free system memory from Linux based systems.
#
# Date: 2007-11-12
# Author: Thomas Borger - ESG
# Date: 2012-04-02
# Modified: Norman Harman - norman.harman@mutualmobile.com
# Date: 2015-04-23
# Modified Peter Viertel <peter@viertel.org>

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

FREE_KB=$( (grep MemAvailable: /proc/meminfo || free | grep buffers/cache | awk '{ print $3,$4 }' ) | awk '{ print $2 }')

if [ "$FREE_KB" = "" ]; then
  echo "MEM UNKNOWN -"
  exit 3
fi

FREE_MEMORY=$((($FREE_KB+512)/1024))

if [ "$perform" = "yes" ]; then
  output="free system memory: $FREE_MEMORY MB | free memory="$FREE_MEMORY"MB;$WARN;$CRIT;0"
else
  output="free system memory: $FREE_MEMORY MB"
fi

if (( $FREE_MEMORY <= $CRIT )); then
  echo "MEM CRITICAL - $output"
  exit 2
elif (( $FREE_MEMORY <= $WARN )); then
  echo "MEM WARNING - $output"
  exit 1
else
  echo "MEM OK - $output"
  exit 0
fi
