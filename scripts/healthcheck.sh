#!/bin/sh

DEFAULT_TCP_PORT=443

if [ -z "$ZT_TCP_PORT" ]; then

    export PORT="${DEFAULT_TCP_PORT}"

else

    export PORT="${ZT_TCP_PORT}"

fi

nc -vz localhost $PORT > /dev/null 2>&1; netcatcode=$?

if [ $netcatcode -eq 0 ]; then
    exit 0  # Service is running, healthcheck passes
else
    nc -vz localhost $PORT
    exit 1  # Something is wrong, not all healthchecks are okay
fi
