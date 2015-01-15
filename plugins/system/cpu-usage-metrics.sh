#!/bin/bash

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
        PID="$OPTARG"
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

get_idle_total()
{
  CPU=(`sed -n 's/^cpu \+//p' /proc/stat`)
  IDLE=${CPU[3]}
  TOTAL=0
  for VALUE in ${CPU[@]}; do
    let "TOTAL=$TOTAL+$VALUE"
  done
}

get_proc()
{
  PROC=`cat /proc/${PID}/stat | awk '{total = $14 + $15; print total}'`
}

get_proc_name()
{
  PROCNAME=`cat /proc/${PID}/stat | awk '{gsub(/[),(]/,""); print $2}'`
}

if [ ! -z "$PIDFILE" ]; then
  if [ ! -s $PIDFILE ]; then
    echo "PID file ${PID} does not exist"
    exit 1
  fi
  PID=`cat ${PIDFILE}`
  get_proc_name
  SCHEME="${SCHEME}.${PROCNAME}"
fi

if [ -z "$PID" ]; then
  get_idle_total

  PREV_TOTAL=$TOTAL
  PREV_IDLE=$IDLE

  sleep 1

  get_idle_total

  let "DIFF_IDLE=$IDLE-$PREV_IDLE"
  let "DIFF_TOTAL=$TOTAL-$PREV_TOTAL"
  let "CPU_USAGE=(($DIFF_TOTAL-$DIFF_IDLE)*1000/$DIFF_TOTAL+5)/10"
else
  if [ ! -f /proc/${PID}/stat ]; then
    echo "/proc/$PID/stat does not exist"
    exit 1
  fi

  get_idle_total
  get_proc

  PREV_TOTAL=$TOTAL
  PREV_PROC=$PROC

  sleep 1

  get_idle_total
  get_proc

  let "DIFF_PROC=$PROC-$PREV_PROC"
  let "DIFF_TOTAL=$TOTAL-$PREV_TOTAL"
  let "CPU_USAGE=(($DIFF_PROC*1000/$DIFF_TOTAL)+5)/10"

fi

echo "$SCHEME.cpu.usage $CPU_USAGE `date +%s`"
