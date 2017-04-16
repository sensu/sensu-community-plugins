#!/bin/sh

# this needs FreeBSD > 10.0 as it introduces the freebsd-version command

HAS_FREEBSD_VERSION=$(which freebsd-version)

if [ -z ${HAS_FREEBSD_VERSION} ]; then
  echo "Only FreeBSD > 10.0 is supported."
  exit 3
fi

RUNNING_KERNEL=$(uname -r)
INSTALLED_KERNEL=$(freebsd-version -k)

if [ "z${RUNNING_KERNEL}" == "z${INSTALLED_KERNEL}" ]; then
  echo "FreeBSD kernel ${RUNNING_KERNEL} up to date."
  exit 0
else
  echo "FreeBSD running kernel is ${RUNNING_KERNEL} and should be ${INSTALLED_KERNEL}."
  exit 2
fi
