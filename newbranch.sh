#!/bin/bash

if test -z "$1"
then
  echo "No branch specified"; exit 1
fi

UPSTREAM="https://github.com/sensu/sensu-community-plugins.git"

git remote -v | grep upstream | grep $UPSTREAM >& /dev/null
if test $? -eq 1
then
  git remote add upstream https://github.com/sensu/sensu-community-plugins.git
fi

BRANCH=$1
git fetch upstream
git branch $BRANCH upstream/master
git checkout $BRANCH
