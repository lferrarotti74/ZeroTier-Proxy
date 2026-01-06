#!/usr/bin/env bash

# Test Helpers for ZeroTier-Proxy BATS Testing Framework
# Provides reusable functions for container management and validation

# Test image name
TEST_IMAGE="zerotier-proxy:test"

# Default ports
DEFAULT_TCP_PORT=443

# Test container name prefix
TEST_CONTAINER_PREFIX="zerotier-proxy-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_success() {
    local message="$1"
    echo -e "${GREEN}✅ $message${NC}"
    return 0
}

print_error() {
    local message="$1"
    echo -e "${RED}❌ $message${NC}"
    return 0
}

print_warning() {
    local message="$1"
    echo -e "${YELLOW}⚠️  $message${NC}"
    return 0
}

print_info() {
    local message="$1"
    echo -e "ℹ️  $message"
    return 0
}

# Read version from env file
get_version_from_env() {
    local env_file="env/.env"
    if [[ -f "$env_file" ]]; then
        # Extract ZEROTIERPROXY_VERSION from .env file
        grep "^ZEROTIERPROXY_VERSION=" "$env_file" | cut -d'=' -f2 | tr -d '"' | tr -d "'"
    else
        print_warning "Environment file not found: $env_file"
        echo "1.14.2"  # fallback version
    fi
    return 0
}

# Build the test image (only if it doesn't exist)
build_test_image() {
    # Check if image already exists
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${TEST_IMAGE}$"; then
        print_success "Test image already exists: $TEST_IMAGE (skipping build)"
        return 0
    fi
    
    # Get version from env file
    local version
    version=$(get_version_from_env)
    
    print_info "Building test image: $TEST_IMAGE (VERSION=$version)"
    docker build --build-arg VERSION="$version" -t "$TEST_IMAGE" . >&3 2>&3
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "Test image built successfully: $TEST_IMAGE"
    else
        print_error "Failed to build test image: $TEST_IMAGE"
    fi
    
    return $exit_code
}

# Setup test environment
setup_test_environment() {
    # Ensure test image exists
    build_test_image
    
    # Clean up any existing test containers
    cleanup_test_containers
    return 0
}

# Cleanup test environment
teardown_test_environment() {
    cleanup_test_containers
    return 0
}

# Clean up test containers
cleanup_test_containers() {
    local containers
    containers=$(docker ps -a --filter "name=${TEST_CONTAINER_PREFIX}" --format "{{.Names}}" 2>/dev/null)
    
    if [[ -n "$containers" ]]; then
        echo "Cleaning up test containers: $containers"
        echo "$containers" | xargs -r docker rm -f >/dev/null 2>&1
    fi
    return 0
}

# Generate unique container name
generate_container_name() {
    echo "${TEST_CONTAINER_PREFIX}-$(date +%s)-$$"
    return 0
}

# Run container with shell command and capture output
run_shell_container_output() {
    local cmd="$1"
    local extra_args="${2:-}"
    
    docker run --rm ${extra_args} --entrypoint="" "${TEST_IMAGE}" sh -c "${cmd}" 2>&1
    return $?
}

# Run container with shell command (no output capture)
run_shell_container() {
    local cmd="$1"
    local extra_args="${2:-}"
    
    docker run --rm ${extra_args} --entrypoint="" "${TEST_IMAGE}" sh -c "${cmd}"
    return $?
}

# Run container with entrypoint and capture output
run_proxy_container_output() {
    local extra_args="${1:-}"
    local timeout="${2:-5}"
    
    timeout "${timeout}s" docker run --rm ${extra_args} "${TEST_IMAGE}" 2>&1 || true
    return $?
}

# Start container in background and return container ID
start_proxy_container_background() {
    local container_name="$1"
    local extra_args="${2:-}"
    
    docker run -d --name "${container_name}" ${extra_args} "${TEST_IMAGE}"
    return $?
}

# Wait for container to be healthy
wait_for_container_healthy() {
    local container_name="$1"
    local timeout="${2:-30}"
    local interval="${3:-2}"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local health_status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "${container_name}" 2>/dev/null || echo "none")
        
        if [[ "$health_status" == "healthy" ]]; then
            return 0
        fi
        
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    return 1
}

# Wait for port to be available in container
wait_for_port() {
    local container_name="$1"
    local port="${2:-$DEFAULT_TCP_PORT}"
    local timeout="${3:-30}"
    local interval="${4:-1}"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if docker exec "${container_name}" nc -z localhost "$port" 2>/dev/null; then
            return 0
        fi
        
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    return 1
}

# Get container logs
get_container_logs() {
    local container_name="$1"
    local lines="${2:-50}"
    
    docker logs --tail "$lines" "$container_name" 2>&1
    return $?
}

# Check if container is running
is_container_running() {
    local container_name="$1"
    
    docker ps --filter "name=${container_name}" --format "{{.Names}}" | grep -q "^${container_name}$"
    return $?
}

# Get container exit code
get_container_exit_code() {
    local container_name="$1"
    
    docker inspect --format='{{.State.ExitCode}}' "$container_name" 2>/dev/null || echo "255"
    return 0
}

# Validate JSON output
validate_json() {
    local json_string="$1"
    
    echo "$json_string" | jq . >/dev/null 2>&1
    return $?
}

# Check if string contains pattern
contains_pattern() {
    local string="$1"
    local pattern="$2"
    
    [[ "$string" =~ $pattern ]]
    return $?
}

# Check file permissions in container
check_file_permissions() {
    local file_path="$1"
    local expected_perms="$2"
    local extra_args="${3:-}"
    
    local actual_perms
    actual_perms=$(run_shell_container_output "stat -c '%a' '${file_path}'" "$extra_args")
    
    [[ "$actual_perms" == "$expected_perms" ]]
    return $?
}

# Check file ownership in container
check_file_ownership() {
    local file_path="$1"
    local expected_owner="$2"
    local expected_group="$3"
    local extra_args="${4:-}"
    
    local ownership_info
    ownership_info=$(run_shell_container_output "stat -c '%U:%G' '${file_path}'" "$extra_args")
    
    [[ "$ownership_info" == "${expected_owner}:${expected_group}" ]]
    return $?
}

# Check if process is running in container
check_process_running() {
    local container_name="$1"
    local process_name="$2"
    
    docker exec "$container_name" pgrep "$process_name" >/dev/null 2>&1
    return $?
}

# Get process count in container
get_process_count() {
    local container_name="$1"
    local process_name="$2"
    
    docker exec "$container_name" pgrep -c "$process_name" 2>/dev/null || echo "0"
    return 0
}

# Test network connectivity from container
test_network_connectivity() {
    local container_name="$1"
    local host="$2"
    local port="$3"
    local timeout="${4:-5}"
    
    docker exec "$container_name" timeout "$timeout" nc -z "$host" "$port" 2>/dev/null
    return $?
}

# Create test configuration file
create_test_config() {
    local tcp_port="${1:-$DEFAULT_TCP_PORT}"
    
    cat <<EOF
{
    "settings": {
        "tcpPort": ${tcp_port}
    }
}
EOF
    return 0
}

# Validate container security settings
validate_container_security() {
    local container_name="$1"
    
    # Check if running as non-root user
    local user_id
    user_id=$(docker exec "$container_name" id -u 2>/dev/null)
    
    if [[ "$user_id" != "0" ]]; then
        print_success "Container running as non-root user (UID: $user_id)"
        return 0
    else
        print_error "Container running as root user"
        return 1
    fi
}

# Check container resource limits
check_container_resources() {
    local container_name="$1"
    
    # Get memory and CPU limits
    local memory_limit
    local cpu_limit
    
    memory_limit=$(docker inspect --format='{{.HostConfig.Memory}}' "$container_name" 2>/dev/null)
    cpu_limit=$(docker inspect --format='{{.HostConfig.CpuShares}}' "$container_name" 2>/dev/null)
    
    echo "Memory limit: ${memory_limit:-unlimited}"
    echo "CPU shares: ${cpu_limit:-default}"
    return 0
}

# Validate environment variables
validate_environment_variables() {
    local container_name="$1"
    shift
    local expected_vars=("$@")
    
    for var in "${expected_vars[@]}"; do
        local var_value
        var_value=$(docker exec "$container_name" printenv "$var" 2>/dev/null || echo "")
        
        if [[ -n "$var_value" ]]; then
            print_success "Environment variable $var is set: $var_value"
        else
            print_warning "Environment variable $var is not set"
        fi
    done
    return 0
}

# Test container with different configurations
test_container_with_config() {
    local config_content="$1"
    local extra_args="${2:-}"
    local container_name
    
    container_name=$(generate_container_name)
    
    # Create temporary config file
    local temp_config="/tmp/zerotier-test-config-$$.json"
    echo "$config_content" > "$temp_config"
    
    # Start container with config
    docker run -d --name "$container_name" \
        -v "$temp_config:/var/lib/zerotier-one/local.conf:ro" \
        $extra_args \
        "$TEST_IMAGE"
    
    # Cleanup function
    cleanup_config_test() {
        docker rm -f "$container_name" >/dev/null 2>&1 || true
        rm -f "$temp_config"
        return 0
    }
    
    echo "$container_name"
    return 0
}

# Export functions for use in BATS tests
export -f get_version_from_env
export -f build_test_image
export -f setup_test_environment
export -f teardown_test_environment
export -f cleanup_test_containers
export -f generate_container_name
export -f run_shell_container_output
export -f run_shell_container
export -f run_proxy_container_output
export -f start_proxy_container_background
export -f wait_for_container_healthy
export -f wait_for_port
export -f get_container_logs
export -f is_container_running
export -f get_container_exit_code
export -f validate_json
export -f contains_pattern
export -f check_file_permissions
export -f check_file_ownership
export -f check_process_running
export -f get_process_count
export -f test_network_connectivity
export -f create_test_config
export -f validate_container_security
export -f check_container_resources
export -f validate_environment_variables
export -f test_container_with_config
export -f print_success
export -f print_error
export -f print_warning
export -f print_info