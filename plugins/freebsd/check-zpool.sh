#!/bin/sh

# check for zpool health
ZPOOL=`which zpool`
EXITSTATUS=0
IFS=$'\n'

for line in $(${ZPOOL} list -o name,health | grep -v NAME | grep -v ONLINE)
do
  echo $line
  EXITSTATUS=2
done

if [ $EXITSTATUS == 0 ]; then
  echo "All pools are healthy."
fi

exit $EXITSTATUS
