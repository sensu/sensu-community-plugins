#!/bin/bash
#
# Check the SMART health status of physical disks
#
# Date: 30/10/13
# Author: Nick Barrett - EDITD
# License: MIT
#
# USes lsblk & smartctl


# get devices (capture /dev/sd* and /dev/hd*)
DEVICES=$( lsblk | awk '/ disk *$/ {print $1}' )
# store fails
FAILS=()

# loop devices
for DEVICE in $DEVICES; do
	# get device status
	STATUS=$( smartctl -H /dev/$DEVICE | grep PASSED > /dev/null && echo "OK" )

	# push to fails
	if ! [ "$STATUS" == "OK" ]; then
		FAILS[${#FAILS[@]}]=$DEVICE
	fi
done

# number of failed devices
FAILCOUNT=${#FAILS[@]}

# fails?
if [ ! $FAILCOUNT == 0 ]; then
	RETURN=""

	for (( i=0; i<$FAILCOUNT; i++ )); do
		RETURN="$RETURN /dev/${FAILS[$i]}"
	done

	echo "DISKS FAILING - $RETURN"
	exit 2
fi

# all ok, return normal
echo "DISK HEALTH OK"
exit 0