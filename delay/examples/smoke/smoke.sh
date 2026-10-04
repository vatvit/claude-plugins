#!/usr/bin/env bash
# The delay smoke job's wrapper: runs inside the container, prints when it ran, writes nothing.
echo "delay smoke job: started $(date '+%Y-%m-%d %H:%M:%S %Z') on $(uname -sm)"
sleep 20
echo "delay smoke job: done"
