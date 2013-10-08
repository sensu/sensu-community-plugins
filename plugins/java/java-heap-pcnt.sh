#!/usr/bin/env bash
#
# Evaluate percentage of heap usage on specfic Tomcat backed JVM from Linux based systems based on percentage
# This was forked from Sensu Community Plugins
# Date: 2007-11-12
# Author: Thomas Borger - ESG
# Date: 2012-04-02
# Modified: Norman Harman - norman.harman@mutualmobile.com
# Date: 2013-9-30
# Modified: Mario Harvey - Zumetrics

# You must have openjdk-7-jdk and openjdk-7-jre packages installed
# http://openjdk.java.net/install/

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

WARN=${WARN:=0}
CRIT=${CRIT:=0}
#Get PID of JVM. 
#At this point grep for the name of the java process running your jvm.
PID=$(jps | grep Bootstrap | awk '{ print $1}')

#Get heap capacity of JVM
TotalHeap=$(jstat -gccapacity $PID  | tail -n 1 | awk '{ print ($4 + $5 + $6 + $10) / 1024 }')

#Determine amount of used heap JVM is using
UsedHeap=$(jstat -gc $PID  | tail -n 1 | awk '{ print ($3 + $4 + $6 + $10) / 1024 }')

#Get heap usage percentage 
HeapPer=$(echo "scale=3; $UsedHeap / $TotalHeap * 100" | bc -l| cut -d "." -f1)


if [ "$HeapPer" = "" ]; then
  echo "MEM UNKNOWN -"
  exit 3
fi

if [ "$perform" = "yes" ]; then
  output="jvm heap usage: $HeapPer% | heap usage="$HeapPer"%;$WARN;$CRIT;0"
else
  output="jvm heap usage: $HeapPer%"
fi

if (( $HeapPer >= $CRIT )); then
  echo "MEM CRITICAL - $output"
  exit 2
elif (( $HeapPer >= $WARN )); then
  echo "MEM WARNING - $output"
  exit 1
else
  echo "MEM OK - $output"
  exit 0
fi
