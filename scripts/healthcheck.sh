#!/bin/sh

nc -vz localhost 443 > /dev/null 2>&1; netcatcode=$?

if [ $netcatcode -eq 0 ]; then
    exit 0  # Service is running, healthcheck passes
else
    nc -vz localhost 443
    exit 1  # Something is wrong, not all healthchecks are okay
fi
