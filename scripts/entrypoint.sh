#!/bin/sh

get_pid() {
  PID=$(pidof /usr/sbin/tcp-proxy)
  return 0
}

grepzt() {
  [ -f /var/lib/zerotier-one/zerotier-proxy.pid -a -n "$(cat /var/lib/zerotier-one/zerotier-proxy.pid 2>/dev/null)" -a -d "/proc/$(cat /var/lib/zerotier-one/zerotier-proxy.pid 2>/dev/null)" ]
  return $?
}

killzerotierproxy() {
  log "Killing Zerotier TCP Proxy"
  kill "$(cat /var/lib/zerotier-one/zerotier-proxy.pid 2>/dev/null)"
  exit 0
}

log_header() {
  printf "\r=>\n" 
  return 0
}

log_detail_header() {
  printf "\r===>\n"
  return 0
}

log() {
  echo "$(log_header)" "$@"
  return 0
}

log_params() {
  title=$1
  shift
  log "$title" "[$@]"
  return 0
}

log_detail() {
  echo "$(log_detail_header)" "$@"
  return 0
}

log_detail_params() {
  title=$1
  shift
  log_detail "$title" "[$@]"
  return 0
}

trap killzerotierproxy INT TERM

DEFAULT_TCP_PORT=443

# If arguments are provided, execute them instead of starting tcp-proxy
if [ $# -gt 0 ]; then
  exec "$@"
fi

# Create local.conf BEFORE starting tcp-proxy so it reads the correct config
if [ "$ZT_OVERRIDE_LOCAL_CONF" = 'true' ] ; then
  echo "{
    \"settings\": {
        \"tcpPort\": ${ZT_TCP_PORT:-$DEFAULT_TCP_PORT}
    }
  }" > /var/lib/zerotier-one/local.conf
fi

get_pid

# If tcp-proxy is already running and we have a custom config, restart it
if [ -n "$PID" ] && [ "$ZT_OVERRIDE_LOCAL_CONF" = 'true' ] && [ -n "$ZT_TCP_PORT" ]; then
  log_detail "Restarting ZeroTier TCP Proxy to apply new configuration"
  kill "$PID"
  # Wait for process to stop
  while kill -0 "$PID" 2>/dev/null; do
    sleep 0.1
  done
  PID=""
fi

if [ -z "$PID" ]
then
  log_detail "Starting ZeroTier TCP Proxy"
  nohup /usr/sbin/tcp-proxy &
fi

if [ -z "$ZT_TCP_PORT" ]; then

  while ! nc -z localhost $DEFAULT_TCP_PORT; do   
    sleep 0.1 # wait for 1/10 of the second before check again
  done

else

  while ! nc -z localhost $ZT_TCP_PORT; do   
    sleep 0.1 # wait for 1/10 of the second before check again
  done

fi

get_pid
echo "$PID" > /var/lib/zerotier-one/zerotier-proxy.pid

while ! grepzt
do
  log_detail "ZeroTier TCP Proxy hasn't started, waiting a second"

  if [ -f nohup.out ]
  then
    tail -n 10 nohup.out
  fi

  sleep 1
done

log "Sleeping infinitely"
while true
do
  sleep 1
done