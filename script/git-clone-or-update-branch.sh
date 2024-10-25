#!/usr/bin/env bash

# this script (inspired by https://stackoverflow.com/a/3278427/68115) will:
# - clone (exit-code 1)
# - pull (exit-code 2)
# - do nothing (exit-code 0)
#
# the exit code can be used to determine if a (re)build action should
# be taken, depending on whether or not the sourcecode has changed

origin=${1}
local=${2}
branch=${3:-main}

if [ -d ${local}/.git ]; then
    git --git-dir=${local}/.git --work-tree=${local} remote update
    local_head=$(git --git-dir=${local}/.git --work-tree=${local} rev-parse @)
    origin_head=$(git --git-dir=${local}/.git --work-tree=${local} rev-parse origin/${branch})
    base=$(git --git-dir=${local}/.git --work-tree=${local} merge-base @ origin/${branch})
    if [ ${local_head} = ${origin_head} ]; then
        # local is up to date with origin
        exit 0
    elif [ ${local_head} = ${base} ]; then
        # local is behind origin (pull required)
        git --git-dir=${local}/.git --work-tree=${local} pull origin origin/${branch}
        exit 2
    elif [ ${origin_head} = ${base} ]; then
        # local is ahead of origin (push required)
        exit 3
    else
        # local has diverged from origin
        exit 4
    fi
else
    git clone ${origin} --branch ${branch} --single-branch ${local}
    exit 1
fi
