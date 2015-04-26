#!/bin/sh

# check to figure out if packages need to be updated

NUMBER=$(pkg audit -q | wc -l | sed -e "s/ //g")

if [ ${NUMBER} -gt 0 ] ; then
  echo "There are ${NUMBER} vulnerable packages: $(pkg audit -q)"
  exit 2
else
  echo "There are no vulnerable packages."
  exit 0
fi
