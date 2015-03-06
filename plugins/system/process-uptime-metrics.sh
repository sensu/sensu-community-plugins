#!/bin/bash

#Author: Abhishek Jain<abhi111jain@gmail.com

#This script greps for a process if the process name is specified or looks for the pid file in case the path to the pid file is specified.
#If the grep is successful in the former case or the pid file is present with a valid running state in the latter case, a value of 1 is 
#associated with the metric (<metric_name> <metric value> <timestamp>) format and outputted otherwise a value of 0 is emitted with the same format.
#The metric name is constructed based on the scheme prefix specified. If not specified, the hostname is picked as the metric scheme and the metric
#name is <hostname>.<process_name>.<uptime>

#Example run
#
# process-uptime-metrics.sh -f <path_to_pid_file> -s <scheme like uptime.metrics.hostname.my_process
#
# The above would emit a line in the following format "uptime.metrics.hostname.uptime.my_process <value(0/1)> <timestamp>"
#
#Alternatively (using the process name instead of the pid file
#
# process-uptime-metrics.sh -p my_process -s uptime.metrics.hostname
#
# Output: "uptime.metrics.hostname.my_process <value(0/1)> <timestamp>"
#
#


# #RED
SCHEME=`hostname`

usage()
{
  cat <<EOF
usage: $0 options

This plugin produces CPU usage (%)

OPTIONS:
   -h      Show this message
   -p      PID
   -f      Path to PID file
   -s      Metric naming scheme, text to prepend to cpu.usage (default: $SCHEME)
EOF
}

while getopts "hp:f:s:" OPTION
  do
    case $OPTION in
      h)
        usage
        exit 1
        ;;
      p)
        PROCESS="$OPTARG"
        ;;
      s)
        SCHEME="$OPTARG"
        ;;
      f)
        PIDFILE="$OPTARG"
        ;;
      ?)
        usage
        exit 1
        ;;
    esac
done

if [ ${PROCESS} ]; then
  scriptname=`basename $0`
  SCHEME="${SCHEME}.${PROCESS}"
  ret=`ps aux | grep "${PROCESS}" | grep -v grep | grep -v $scriptname`
  if [ ! "${ret}" ]; then
    echo "$SCHEME.uptime 0 `date +%s`"
    exit 0
  fi
  echo "$SCHEME.uptime 1 `date +%s`"
  exit 0
fi

if [ ${PIDFILE} ]; then
  if [ ! -e ${PIDFILE} ]; then
    echo "$SCHEME.uptime 0 `date +%s`"
    exit 0
  fi
  pid=`cat ${PIDFILE} | tr -d ' '`
  if [ ! -f /proc/${pid}/status ]; then
    echo "$SCHEME.uptime 0 `date +%s`"
    exit 0
  fi
  echo "$SCHEME.uptime 1 `date +%s`"
  exit 0
fi
