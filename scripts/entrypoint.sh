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
  return 0
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

log_info() {
  echo "[INFO] $1"
  return 0
}

log_error() {
  echo "[ERROR] $1" >&2
  return 0
}

trap killzerotierproxy INT TERM

DEFAULT_TCP_PORT=443
CONFIG_FILE="/var/lib/zerotier-one/local.conf"

check_required_vars() {
  local provider="$1"
  local missing_vars=false

  if [ -z "$ZT_CLOUD_API_TOKEN" ]; then
    log_error "ZT_CLOUD_API_TOKEN is required"
    missing_vars=true
  fi

  if [ -z "$ZT_CLOUD_FIREWALL_ID" ]; then
    log_error "ZT_CLOUD_FIREWALL_ID is required"
    missing_vars=true
  fi

  case "$provider" in
    aws)
      if [ -z "$ZT_CLOUD_AWS_REGION" ]; then
        log_error "ZT_CLOUD_AWS_REGION is required"
        missing_vars=true
      fi
      if [ -z "$ZT_CLOUD_AWS_SECRET_KEY" ]; then
        log_error "ZT_CLOUD_AWS_SECRET_KEY is required"
        missing_vars=true
      fi
      ;;
    azure)
      if [ -z "$ZT_CLOUD_AZURE_TENANT_ID" ]; then
        log_error "ZT_CLOUD_AZURE_TENANT_ID is required"
        missing_vars=true
      fi
      if [ -z "$ZT_CLOUD_AZURE_SUBSCRIPTION_ID" ]; then
        log_error "ZT_CLOUD_AZURE_SUBSCRIPTION_ID is required"
        missing_vars=true
      fi
      if [ -z "$ZT_CLOUD_AZURE_RESOURCE_GROUP" ]; then
        log_error "ZT_CLOUD_AZURE_RESOURCE_GROUP is required"
        missing_vars=true
      fi
      ;;
    gcp)
      if [ -z "$ZT_CLOUD_GCP_PROJECT_ID" ]; then
        log_error "ZT_CLOUD_GCP_PROJECT_ID is required"
        missing_vars=true
      fi
      ;;
    linode)
      ;;
    *)
      log_error "Unknown cloud provider: $provider"
      return 1
      ;;
  esac

  if [ "$missing_vars" = true ]; then
    return 1
  fi

  return 0
}

generate_cloud_config() {
  local provider="$1"
  local config

  config="    \"cloudProvider\": \"$provider\",\n"
  config="$config    \"cloudApiToken\": \"$ZT_CLOUD_API_TOKEN\",\n"
  config="$config    \"cloudFirewallId\": \"$ZT_CLOUD_FIREWALL_ID\""

  case "$provider" in
    aws)
      config="$config,\n    \"cloudAdditionalParams\": {\n"
      config="$config      \"secretKey\": \"$ZT_CLOUD_AWS_SECRET_KEY\",\n"
      config="$config      \"region\": \"$ZT_CLOUD_AWS_REGION\"\n"
      config="$config    }"
      ;;
    azure)
      config="$config,\n    \"cloudAdditionalParams\": {\n"
      config="$config      \"tenantId\": \"$ZT_CLOUD_AZURE_TENANT_ID\",\n"
      config="$config      \"subscriptionId\": \"$ZT_CLOUD_AZURE_SUBSCRIPTION_ID\",\n"
      config="$config      \"resourceGroup\": \"$ZT_CLOUD_AZURE_RESOURCE_GROUP\"\n"
      config="$config    }"
      ;;
    gcp)
      config="$config,\n    \"cloudAdditionalParams\": {\n"
      config="$config      \"projectId\": \"$ZT_CLOUD_GCP_PROJECT_ID\""
      if [ -n "$ZT_CLOUD_GCP_NETWORK" ]; then
        config="$config,\n      \"network\": \"$ZT_CLOUD_GCP_NETWORK\""
      fi
      config="$config\n    }"
      ;;
    linode)
      ;;
  esac

  printf "%b\n" "$config"
  return 0
}

generate_local_conf() {
  local tcp_port
  local config
  local cloud_config

  tcp_port="${ZT_TCP_PORT:-$DEFAULT_TCP_PORT}"
  config="{\n"
  config="$config  \"settings\": {\n"
  config="$config    \"tcpPort\": $tcp_port"

  if [ -n "$ZT_EXT_TCP_PORT" ]; then
    config="$config,\n    \"externalTcpPort\": $ZT_EXT_TCP_PORT"
  fi

  if [ -n "$ZT_CLOUD_PROVIDER" ]; then
    if check_required_vars "$ZT_CLOUD_PROVIDER"; then
      cloud_config="$(generate_cloud_config "$ZT_CLOUD_PROVIDER")"
      config="$config,\n$cloud_config"
    else
      log_error "Missing required cloud variables. Using basic config."
    fi
  elif [ -n "$ZT_LINODE_API_TOKEN" ] && [ -n "$ZT_LINODE_FIREWALL_ID" ]; then
    config="$config,\n    \"cloudProvider\": \"linode\",\n"
    config="$config    \"cloudApiToken\": \"$ZT_LINODE_API_TOKEN\",\n"
    config="$config    \"cloudFirewallId\": \"$ZT_LINODE_FIREWALL_ID\""
  fi

  if [ "$ZT_LOG_STDOUT" = "true" ]; then
    config="$config,\n    \"logStdout\": true"
  fi

  config="$config\n  }\n}"
  printf "%b\n" "$config"
  return 0
}

# If arguments are provided, execute them instead of starting tcp-proxy
if [ $# -gt 0 ]; then
  exec "$@"
fi

if [ "$ZT_OVERRIDE_LOCAL_CONF" = 'true' ] ; then
  generate_local_conf > "$CONFIG_FILE"
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
