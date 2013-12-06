#!/usr/bin/env bash
#
# Collect metrics on your JVM and allow you to trace usage in graphite

# Modified: Mario Harvey - badmadrad.com

# You must have openjdk-7-jdk and openjdk-7-jre packages installed
# http://openjdk.java.net/install/

# Also make sure the user "sensu" can sudo without password
while getopts 's:n:h' OPT; do
case $OPT in
s) SCHEME=$OPTARG;;
n) NAME=$OPTARG;;
h) hlp="yes";;
esac
done
#usage
HELP="
        usage $0 [ -n value -s value -h ]
                -n --> NAME or name of jvm process < value
		-s --> SCHEME or server name ex. :::name::: < value
                -h --> print this help screen
"
if [ "$hlp" = "yes" ]; then
        echo "$HELP"
        exit 0
        fi

SCHEME=${SCHEME:=0}
NAME=${NAME:=0}

#Get PID of JVM.
#At this point grep for the name of the java process running your jvm.
PID=$(sudo jps | grep $NAME | awk '{ print $1}')

#Get heap capacity of JVM
TotalHeap=$(sudo jstat -gccapacity $PID  | tail -n 1 | awk '{ print ($4 + $5 + $6 + $10) / 1024 }')

#Determine amount of used heap JVM is using
UsedHeap=$(sudo jstat -gc $PID  | tail -n 1 | awk '{ print ($3 + $4 + $6 + $8 + $10) / 1024 }')

#Determine Old Space Utilization
OldGen=$(sudo jstat -gc $PID  | tail -n 1 | awk '{ print ($8) / 1024 }')

#Determine Permanent Space Utilization
PermGen=$(sudo jstat -gc $PID  | tail -n 1 | awk '{ print ($10) / 1024 }')

#Determine Eden Space Utilization
ParEden=$(sudo jstat -gc $PID  | tail -n 1 | awk '{ print ($6) / 1024 }')

#Determine Survivor Space utilization
ParSurv=$(sudo jstat -gc $PID  | tail -n 1 | awk '{ print ($3 + $4) / 1024 }')

echo "JVMs.$SCHEME.Committed_Heap $TotalHeap `date '+%s'`"
echo "JVMs.$SCHEME.Used_Heap $UsedHeap `date '+%s'`"
echo "JVMs.$SCHEME.Eden_Util $ParEden `date '+%s'`"
echo "JVMs.$SCHEME.Survivor_Util $ParSurv `date '+%s'`"
echo "JVMs.$SCHEME.Old_Util $OldGen `date '+%s'`"
echo "JVMs.$SCHEME.Perm_Util $PermGen `date '+%s'`"
