#!/usr/bin/env bats

# Entrypoint Script Tests for ZeroTier-Proxy
# Tests entrypoint.sh functionality, startup logic, and configuration handling

load '../helpers/test_helpers'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

# =============================================================================
# Entrypoint Script Validation Tests
# =============================================================================

@test "Entrypoint script should exist and be executable" {
    run run_shell_container_output "ls -la /entrypoint.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "-rwxr-xr-x" ]]
    [[ "$output" =~ "/entrypoint.sh" ]]
    print_success "Entrypoint script exists and is executable"
}

@test "Entrypoint script should have correct shebang" {
    run run_shell_container_output "head -1 /entrypoint.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "#!/bin/sh" ]]
    print_success "Entrypoint script has correct shebang"
}

@test "Entrypoint script should contain required functions" {
    run run_shell_container_output "grep -E '^(get_pid|grepzt|killzerotierproxy|log)' /entrypoint.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "get_pid" ]]
    [[ "$output" =~ "grepzt" ]]
    [[ "$output" =~ "killzerotierproxy" ]]
    [[ "$output" =~ "log" ]]
    print_success "Entrypoint script contains required functions"
}

# =============================================================================
# Configuration Handling Tests
# =============================================================================

@test "Entrypoint should handle default TCP port configuration" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for initialization
    sleep 5
    
    # Check if default port 443 is being used
    run docker exec "$container_name" netstat -tlnp 2>/dev/null || docker exec "$container_name" ss -tlnp 2>/dev/null
    [ "$status" -eq 0 ]
    [[ "$output" =~ ":443" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint handles default TCP port (443) correctly"
}

@test "Entrypoint should handle custom ZT_TCP_PORT environment variable" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name" "-e ZT_TCP_PORT=8443 -e ZT_OVERRIDE_LOCAL_CONF=true"
    [ "$status" -eq 0 ]
    
    # Wait for initialization
    sleep 5
    
    # Check if custom port is being used
    run docker exec "$container_name" netstat -tlnp 2>/dev/null || docker exec "$container_name" ss -tlnp 2>/dev/null
    [ "$status" -eq 0 ]
    [[ "$output" =~ ":8443" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint handles custom ZT_TCP_PORT environment variable"
}

@test "Entrypoint should create local.conf when ZT_OVERRIDE_LOCAL_CONF is true" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name" "-e ZT_OVERRIDE_LOCAL_CONF=true -e ZT_TCP_PORT=9443"
    [ "$status" -eq 0 ]
    
    # Wait for initialization
    sleep 5
    
    # Check if local.conf was created
    run docker exec "$container_name" test -f /var/lib/zerotier-one/local.conf
    [ "$status" -eq 0 ]
    
    # Check content of local.conf
    run docker exec "$container_name" cat /var/lib/zerotier-one/local.conf
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tcpPort" ]]
    [[ "$output" =~ "9443" ]]
    
    # Validate JSON format
    run docker exec "$container_name" jq . /var/lib/zerotier-one/local.conf
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint creates valid local.conf when ZT_OVERRIDE_LOCAL_CONF is true"
}

@test "Entrypoint should not create local.conf when ZT_OVERRIDE_LOCAL_CONF is false" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name" "-e ZT_OVERRIDE_LOCAL_CONF=false"
    [ "$status" -eq 0 ]
    
    # Wait for initialization
    sleep 5
    
    # Check if local.conf was NOT created by entrypoint
    # (it might exist from image build, but shouldn't be overwritten)
    local logs
    logs=$(get_container_logs "$container_name" 50)
    
    # Should not contain config creation messages in logs
    [[ ! "$logs" =~ "settings" ]] || [[ ! "$logs" =~ "tcpPort" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint respects ZT_OVERRIDE_LOCAL_CONF=false"
}

# =============================================================================
# Process Management Tests
# =============================================================================

@test "Entrypoint should start tcp-proxy process" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for process to start
    sleep 5
    
    # Check if tcp-proxy process is running
    run check_process_running "$container_name" "tcp-proxy"
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint starts tcp-proxy process successfully"
}

@test "Entrypoint should create PID file for tcp-proxy" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for process to start
    sleep 5
    
    # Check if PID file exists
    run docker exec "$container_name" test -f /var/lib/zerotier-one/zerotier-proxy.pid
    [ "$status" -eq 0 ]
    
    # Check if PID file contains valid PID
    run docker exec "$container_name" cat /var/lib/zerotier-one/zerotier-proxy.pid
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
    
    # Verify PID corresponds to running process
    local pid="$output"
    run docker exec "$container_name" ps -p "$pid"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tcp-proxy" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint creates valid PID file for tcp-proxy"
}

@test "Entrypoint should wait for tcp-proxy to be ready" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for initialization
    sleep 10
    
    # Check container logs for readiness messages
    local logs
    logs=$(get_container_logs "$container_name" 50)
    
    # Should contain startup and readiness messages
    [[ "$logs" =~ "Starting ZeroTier TCP Proxy" ]] || [[ "$logs" =~ "tcp-proxy" ]]
    
    # Port should be listening
    run wait_for_port "$container_name" 443 30
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint waits for tcp-proxy to be ready"
}

@test "Entrypoint should handle tcp-proxy startup failures gracefully" {
    # Test with invalid configuration that might cause startup failure
    local container_name
    container_name=$(generate_container_name)
    
    # Use a privileged port that might fail in unprivileged container
    run start_proxy_container_background "$container_name" "-e ZT_TCP_PORT=80 -e ZT_OVERRIDE_LOCAL_CONF=true"
    [ "$status" -eq 0 ]
    
    # Wait and check container behavior
    sleep 10
    
    # Container might exit or show error logs - both are acceptable
    local logs
    logs=$(get_container_logs "$container_name" 50)
    
    # Should have some log output indicating the attempt
    [[ -n "$logs" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint handles tcp-proxy startup issues gracefully"
}

# =============================================================================
# Signal Handling Tests
# =============================================================================

@test "Entrypoint should handle SIGTERM gracefully" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for process to start
    sleep 5
    
    # Send SIGTERM
    docker kill --signal=TERM "$container_name" >/dev/null 2>&1
    
    # Wait for graceful shutdown
    sleep 5
    
    # Check exit code
    local exit_code
    exit_code=$(get_container_exit_code "$container_name")
    
    # Should exit cleanly (0) or with SIGTERM (143)
    [[ "$exit_code" == "0" || "$exit_code" == "143" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint handles SIGTERM gracefully (exit code: $exit_code)"
}

@test "Entrypoint should handle SIGINT gracefully" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for process to start
    sleep 5
    
    # Send SIGINT
    docker kill --signal=INT "$container_name" >/dev/null 2>&1
    
    # Wait for graceful shutdown
    sleep 5
    
    # Check exit code
    local exit_code
    exit_code=$(get_container_exit_code "$container_name")
    
    # Should exit cleanly (0) or with SIGINT (130)
    [[ "$exit_code" == "0" || "$exit_code" == "130" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint handles SIGINT gracefully (exit code: $exit_code)"
}

# =============================================================================
# Logging and Output Tests
# =============================================================================

@test "Entrypoint should produce informative log output" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for initialization
    sleep 5
    
    # Check container logs
    local logs
    logs=$(get_container_logs "$container_name" 50)
    
    # Should contain informative messages
    [[ -n "$logs" ]]
    
    # Should contain startup-related messages
    [[ "$logs" =~ "ZeroTier" ]] || [[ "$logs" =~ "tcp-proxy" ]] || [[ "$logs" =~ "Starting" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint produces informative log output"
}

@test "Entrypoint should handle nohup.out file properly" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for initialization
    sleep 5
    
    # Check if nohup.out is created and managed properly
    run docker exec "$container_name" test -f nohup.out
    # nohup.out might or might not exist - both are acceptable
    
    # If it exists, it should be readable
    if docker exec "$container_name" test -f nohup.out 2>/dev/null; then
        run docker exec "$container_name" head -5 nohup.out
        [ "$status" -eq 0 ]
    fi
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint handles nohup.out file properly"
}

# =============================================================================
# Port Waiting Logic Tests
# =============================================================================

@test "Entrypoint should wait for default port to be available" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for port to be ready
    run wait_for_port "$container_name" 443 30
    [ "$status" -eq 0 ]
    
    # Verify port is actually listening
    run docker exec "$container_name" nc -z localhost 443
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint waits for default port (443) to be available"
}

@test "Entrypoint should wait for custom port to be available" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name" "-e ZT_TCP_PORT=8443 -e ZT_OVERRIDE_LOCAL_CONF=true"
    [ "$status" -eq 0 ]
    
    # Wait for custom port to be ready
    run wait_for_port "$container_name" 8443 30
    [ "$status" -eq 0 ]
    
    # Verify custom port is actually listening
    run docker exec "$container_name" nc -z localhost 8443
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint waits for custom port (8443) to be available"
}

# =============================================================================
# Infinite Loop and Daemon Behavior Tests
# =============================================================================

@test "Entrypoint should enter infinite sleep loop after initialization" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for initialization
    sleep 10
    
    # Container should still be running (infinite loop)
    run is_container_running "$container_name"
    [ "$status" -eq 0 ]
    
    # Check that entrypoint process is still active
    run docker exec "$container_name" ps aux
    [ "$status" -eq 0 ]
    [[ "$output" =~ "entrypoint.sh" ]] || [[ "$output" =~ "/bin/sh" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint enters infinite sleep loop after initialization"
}

@test "Entrypoint should maintain tcp-proxy process throughout lifecycle" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for initialization
    sleep 5
    
    # Check tcp-proxy is running initially
    run check_process_running "$container_name" "tcp-proxy"
    [ "$status" -eq 0 ]
    
    # Wait longer and check again
    sleep 10
    
    # tcp-proxy should still be running
    run check_process_running "$container_name" "tcp-proxy"
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Entrypoint maintains tcp-proxy process throughout lifecycle"
}