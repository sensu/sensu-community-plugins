#!/bin/bash
#
# Check process
#
# ===
#
# Examples:
#
#   # check by process name
#   check-process.sh -p nginx
#
#   # check by PID file
#   check-process.sh -f /var/spool/postfix/pid/master.pid
#
# Date: 2014-09-12
# Author: Jun Ichikawa <jun1ka0@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

# get arguments
while getopts 'p:f:h' OPT; do
  case $OPT in
    p)  PROCESS=$OPTARG;;
    f)  PID_FILE=$OPTARG;;
    h)  hlp="yes";;
    *)  unknown="yes";;
  esac
done

# usage
HELP="
    usage: $0 [ -p value -f value -h ]

        -p --> process name
        -f --> file path to pid file
        -h --> print this help screen
"

if [ "$hlp" = "yes" ]; then
  echo "$HELP"
  exit 0
fi

if [ ${PROCESS} ]; then
  ret=`ps aux | grep "${PROCESS}" | grep -v grep | grep -v $0`
  if [ ! "${ret}" ]; then
    echo "CRITICAL - process ${PROCESS} does not exist"
    exit 2
  fi
  echo "PROCESS OK - ${PROCESS}"
  exit 0
fi

if [ ${PID_FILE} ]; then
  if [ ! -e ${PID_FILE} ]; then
    echo "CRITICAL - PID file ${PID_FILE} does not exist"
    exit 2
  fi
  pid=`cat ${PID_FILE} | tr -d ' '`
  if [ ! -f /proc/${pid}/status ]; then
    echo "CRITICAL - status of ${PID_FILE} not found"
    exit 2
  fi
  echo "PROCESS OK - ${PID_FILE}"
  exit 0
fi

echo "$HELP"
exit 2
