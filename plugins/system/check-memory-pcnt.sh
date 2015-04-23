#!/usr/bin/env bash
#
# Evaluate free system memory from Linux based systems based on percentage
# This was forked from Sensu Community Plugins
#
# Requires: free
#
# Date: 2007-11-12
# Author: Thomas Borger - ESG
# Date: 2012-04-02
# Modified: Norman Harman - norman.harman@mutualmobile.com
# Date: 2013-9-30
# Modified: Mario Harvey - Zumetrics
# Date: 2015-01-10
# Modified Ollie Armstrong <ollie@armstrong.io>
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

        -w --> Warning Percentage < value
        -c --> Critical Percentage < value
        -p --> print out performance data
        -h --> print this help screen
"

if [ "$hlp" = "yes" ]; then
  echo "$HELP"
  exit 0
fi

WARN=${WARN:=101}
CRIT=${CRIT:=101}

#Get total memory available on machine
TotalMem=$(grep MemTotal: /proc/meminfo | awk '{ print $2 }')
#Determine amount of free memory on the machine
FreeMem=$( (grep MemAvailable: /proc/meminfo || free | grep buffers/cache | awk '{ print $3,$4 }' ) | awk '{ print $2 }')
#Get percentage of free memory
FreePer=$(($FreeMem*100 / $TotalMem))
#Get actual memory usage percentage by subtracting free memory percentage from 100
UsedPer=$((100-$FreePer))


if [ "$UsedPer" = "" ]; then
  echo "MEM UNKNOWN -"
  exit 3
fi

if [ "$perform" = "yes" ]; then
  output="system memory usage: $UsedPer% | free memory="$(($FreeMem/1024))"MB;$WARN;$CRIT;0"
else
  output="system memory usage: $UsedPer%"
fi

if (( $UsedPer >= $CRIT )); then
  echo "MEM CRITICAL - $output"
  exit 2
elif (( $UsedPer >= $WARN )); then
  echo "MEM WARNING - $output"
  exit 1
else
  echo "MEM OK - $output"
  exit 0
fi
