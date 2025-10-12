#!/bin/sh

DEFAULT_TCP_PORT=443

if [ -z "$ZT_TCP_PORT" ]; then

    export PORT="${DEFAULT_TCP_PORT}"

else

    export PORT="${ZT_TCP_PORT}"

fi

# Check if nc command exists and is functional
if ! command -v nc >/dev/null 2>&1; then
    echo "Error: netcat (nc) command not found"
    exit 1
fi

# Test if nc is functional by trying to run it with a simple test
# If nc exits with 127 (command not found), it's likely a fake/broken nc
nc -h >/dev/null 2>&1
nc_help_exit=$?
if [ $nc_help_exit -eq 127 ]; then
    echo "Error: netcat (nc) command is not functional (exit code 127)"
    exit 1
fi

nc -vz localhost $PORT > /dev/null 2>&1; netcatcode=$?

if [ $netcatcode -eq 0 ]; then
    exit 0  # Service is running, healthcheck passes
else
    nc -vz localhost $PORT
    exit 1  # Something is wrong, not all healthchecks are okay
fi
