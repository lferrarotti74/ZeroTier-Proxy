#!/bin/sh

get_pid() {
  PID=$(pidof /usr/sbin/tcp-proxy)
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
}

log_detail_header() {
  printf "\r===>\n"
}

log() {
  echo "$(log_header)" "$@"
}

log_params() {
  title=$1
  shift
  log "$title" "[$@]"
}

log_detail() {
  echo "$(log_detail_header)" "$@"
}

log_detail_params() {
  title=$1
  shift
  log_detail "$title" "[$@]"
}

trap killzerotierproxy INT TERM

get_pid

if [ -z "$PID" ]
then
  log_detail "Starting ZeroTier TCP Proxy"
  nohup /usr/sbin/tcp-proxy &
fi

while ! nc -z localhost 443; do   
  sleep 0.1 # wait for 1/10 of the second before check again
done

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