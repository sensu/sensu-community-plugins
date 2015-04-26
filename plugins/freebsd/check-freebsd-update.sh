#!/bin/sh

# this needs to run with sudo as the tag file is only readable by root

TAGFILE="/var/db/freebsd-update/tag"

if [ ! -f ${TAGFILE} ]; then
  echo "Couldn't find ${TAGFILE} to check for version."
  exit 3
fi

CURRENT_VERSION=$(/bin/freebsd-version)
UPDATE_BASE=$(cut -f 3 -d '|' < ${TAGFILE})
UPDATE_PATCH=$(cut -f 4 -d '|' < ${TAGFILE})
UPDATE_VERSION="${UPDATE_BASE}-p${UPDATE_PATCH}"

if [ "z${CURRENT_VERSION}" == "z${UPDATE_VERSION}" ]; then
  echo "FreeBSD installation up-to-date on ${CURRENT_VERSION}."
  exit 0
else
  echo "FreeBSD installation is on ${CURRENT_VERSION} and should be on ${UPDATE_VERSION}."
  exit 2
fi
