#!/bin/bash
#
# Retrive cgroup metrics on Linux systems
#
# Author: Julian Prokay -- jprokay@gmail.com

# #RED
usage()
{
	cat <<EOF
usage: $0 options
Single usage example: $0 -c cpu -m nr_throttled
Multi-metric, multi-component: $0 -c cpu -c memory -m nr_throttled -m memory
Recursive: $0 -c cpu -m nr_throttled -r -p /libvirt/

This plugin returns the value, or a list of values, for a set of cgroup components and metrics.
The output is formatted for Sensu as: {path} {metric value} {timestamp}

OPTIONS:
	-h Show this message
	-s Scheme. Used as the prefix for the output path.
           Default: stats.{hostname -s}.cgroup
	-c Required. CGroup component(s). Ex: cpu, memory
	-m Required. Metric(s) to get. Ex: nr_throttled
        -p Subdirectory path. Use this to get to a specific cgroup. Combine with
           the -r flag to recursively get cgroup stats
        -r Set recursive. If true, recurse through the subdirectory passed with -p.
           Default: false
EOF
}
declare -a METRICS
declare -a COMPONENTS
metric_counter=0
comps_counter=0
while getopts "hrc:m:s:p:" OPTION
    do
        case $OPTION in
            h)
                usage
                exit 1
                ;;
            c)
                COMPONENTS[$comps_counter]="$OPTARG"
                comps_counter=$comp_counter+1
                ;;
            m)
                METRICS[$metric_counter]="$OPTARG"
                metric_counter=$metric_counter+1
                ;;
            s)
                SCHEME="$OPTARG"
                ;;
            p)
                SUBDIR_PATH="$OPTARG"
                ;;
            r)
                RECURSIVE=true
                ;;
            ?)
                usage
                exit 1
                ;;
        esac
done

#Iterates through the SUBDIR_PATH (if provided and recursive) and then gets cgroup stats
get_cgroup_stats()
{
    if [ -z "$SUBDIR_PATH" ]; then
        get_cgroup_stat "/"
    else
        if [ $RECURSIVE ]; then
            for dir_path in `ls -d /cgroup/${COMPONENTS[0]}/$SUBDIR_PATH/*/`; do
                get_dir=`basename "$dir_path"`
                dir="$SUBDIR_PATH/$get_dir"
                get_cgroup_stat $dir
            done
        else
            get_cgroup_stat "$SUBDIR_PATH"
        fi
    fi
}

#Gets the cgroup data for the specified component and metric
get_cgroup_stat()
{
    for component in "${COMPONENTS[@]}"; do
        counter=0
        for metric in "${METRICS[@]}"; do
            metric_val=`cgget -g $component "$1" | grep $metric | cut -d ' ' -f 2`
            if ! [ -z $metric_val ]; then
                timestamp=`date +%s`
                if [ "$1" = "/" ]; then
                    echo "$SCHEME.$component.$metric $metric_val $timestamp"
                else
                    path="${1//\//.}"
                    echo "$SCHEME.$path.$component.$metric $metric_val $timestamp"
                fi
            fi
            counter=$counter+1
        done
    done
}

if [ "${#COMPONENTS[@]}" -eq 0 ]; then
    echo "Component required"
    exit 1
fi
if [  "${#METRICS[@]}" -eq 0 ]; then
    echo "Metric required"
    exit 1
fi

if [ -z "$SCHEME" ]; then
    SCHEME="stats.`hostname -s`.cgroups"
fi

get_cgroup_stats
