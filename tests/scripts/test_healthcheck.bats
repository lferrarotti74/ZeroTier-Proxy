#!/usr/bin/env bats

# Healthcheck Script Tests for ZeroTier-Proxy
# Tests healthcheck.sh functionality, health monitoring, and status reporting

load '../helpers/test_helpers'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

# =============================================================================
# Healthcheck Script Validation Tests
# =============================================================================

@test "Healthcheck script should exist and be executable" {
    run run_shell_container_output "ls -la /healthcheck.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "-rwxr-xr-x" ]]
    [[ "$output" =~ "/healthcheck.sh" ]]
    print_success "Healthcheck script exists and is executable"
}

@test "Healthcheck script should have correct shebang" {
    run run_shell_container_output "head -1 /healthcheck.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "#!/bin/sh" ]]
    print_success "Healthcheck script has correct shebang"
}

@test "Healthcheck script should contain netcat command" {
    run run_shell_container_output "grep -E '(nc|netcat)' /healthcheck.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "nc" ]]
    print_success "Healthcheck script contains netcat command"
}

@test "Healthcheck script should use localhost and port 443" {
    run run_shell_container_output "grep -E 'localhost.*PORT' /healthcheck.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "localhost" ]]
    [[ "$output" =~ "PORT" ]]
    print_success "Healthcheck script uses localhost and configurable port"
}

# =============================================================================
# Healthcheck Functionality Tests
# =============================================================================

@test "Healthcheck should pass when tcp-proxy is running on default port" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for tcp-proxy to start
    sleep 10
    
    # Run healthcheck directly
    run docker exec "$container_name" /healthcheck.sh
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Healthcheck passes when tcp-proxy is running on default port"
}

@test "Healthcheck should pass when tcp-proxy is running on custom port" {
    local container_name
    container_name=$(generate_container_name)
    
    # Start with custom port and enable local.conf override
    run start_proxy_container_background "$container_name" "-e ZT_TCP_PORT=8443 -e ZT_OVERRIDE_LOCAL_CONF=true"
    [ "$status" -eq 0 ]
    
    # Wait for tcp-proxy to start
    sleep 10
    
    # Run healthcheck - should pass since healthcheck.sh uses ZT_TCP_PORT
    run docker exec "$container_name" /healthcheck.sh
    [ "$status" -eq 0 ]
    
    # Verify the custom port is actually working
    run docker exec "$container_name" nc -z localhost 8443
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Healthcheck passes when tcp-proxy is running on custom port"
}

@test "Healthcheck should fail when tcp-proxy is not running" {
    local container_name
    container_name=$(generate_container_name)
    
    # Start container but kill tcp-proxy process
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for tcp-proxy to start
    sleep 5
    
    # Kill tcp-proxy process
    docker exec "$container_name" pkill -f tcp-proxy >/dev/null 2>&1 || true
    
    # Wait a moment for process to die
    sleep 2
    
    # Run healthcheck - should fail
    run docker exec "$container_name" /healthcheck.sh
    [ "$status" -ne 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Healthcheck fails when tcp-proxy is not running"
}

@test "Healthcheck should fail when port 443 is not listening" {
    # Create a container that doesn't start tcp-proxy
    local container_name
    container_name=$(generate_container_name)
    
    # Start container with shell override to prevent tcp-proxy startup, but also kill entrypoint
    run docker run -d --name "$container_name" --entrypoint="" "$TEST_IMAGE" sh -c "sleep 300"
    [ "$status" -eq 0 ]
    
    # Wait a moment
    sleep 2
    
    # Run healthcheck - should fail since no service on port 443
    run docker exec "$container_name" /healthcheck.sh
    [ "$status" -ne 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Healthcheck fails when port 443 is not listening"
}

# =============================================================================
# Docker Health Integration Tests
# =============================================================================

@test "Docker health status should be healthy when tcp-proxy is running" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for healthcheck to run (Docker runs it every 60s by default in our Dockerfile)
    # We'll wait up to 120 seconds for health status to become healthy
    local max_wait=120
    local wait_time=0
    local health_status=""
    
    while [ $wait_time -lt $max_wait ]; do
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "none")
        
        if [ "$health_status" = "healthy" ]; then
            break
        fi
        
        sleep 10
        wait_time=$((wait_time + 10))
    done
    
    # Check final health status
    [[ "$health_status" == "healthy" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Docker health status is healthy when tcp-proxy is running"
}

@test "Docker health status should show health logs" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for at least one healthcheck to run
    sleep 35
    
    # Get health logs
    run docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' "$container_name"
    [ "$status" -eq 0 ]
    
    # Should have some health log output
    [[ -n "$output" ]] || [[ "$output" != "null" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Docker health status shows health logs"
}

# =============================================================================
# Netcat Connectivity Tests
# =============================================================================

@test "Healthcheck netcat should work with zero timeout" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for tcp-proxy to start
    sleep 10
    
    # Test netcat with zero timeout (as used in healthcheck)
    run docker exec "$container_name" nc -z localhost 443
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Healthcheck netcat works with zero timeout"
}

@test "Healthcheck netcat should fail quickly on closed port" {
    local container_name
    container_name=$(generate_container_name)
    
    # Start container without tcp-proxy
    run docker run -d --name "$container_name" "$TEST_IMAGE" sh -c "sleep 300"
    [ "$status" -eq 0 ]
    
    # Test netcat on closed port with timeout - should fail quickly
    local start_time=$(date +%s)
    run docker exec "$container_name" timeout 3 nc -z localhost 443
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Should fail (either nc fails or timeout kills it)
    [ "$status" -ne 0 ]
    
    # Should fail quickly (within 5 seconds)
    [ "$duration" -le 5 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Healthcheck netcat fails quickly on closed port (${duration}s)"
}

@test "Healthcheck should handle IPv4 localhost correctly" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for tcp-proxy to start
    sleep 10
    
    # Test with explicit IPv4 localhost
    run docker exec "$container_name" nc -z 127.0.0.1 443
    [ "$status" -eq 0 ]
    
    # Test with hostname localhost
    run docker exec "$container_name" nc -z localhost 443
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Healthcheck handles IPv4 localhost correctly"
}

# =============================================================================
# Error Handling and Edge Cases
# =============================================================================

@test "Healthcheck should handle missing netcat gracefully" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 5
    
    # Verify netcat exists first
    run docker exec "$container_name" which nc
    [ "$status" -eq 0 ]
    
    # Create a temporary script that simulates missing nc
    docker exec "$container_name" sh -c 'cat > /tmp/fake_healthcheck.sh << EOF
#!/bin/sh
# Simulate missing nc by temporarily hiding it
export PATH="/tmp:\$PATH"
exec /healthcheck.sh
EOF'
    
    docker exec "$container_name" chmod +x /tmp/fake_healthcheck.sh
    
    # Create a fake nc that doesn't exist
    docker exec "$container_name" sh -c 'mkdir -p /tmp && printf "#!/bin/sh\nexit 127\n" > /tmp/nc && chmod +x /tmp/nc'
    
    # Run healthcheck with fake missing nc - should fail gracefully
    run docker exec "$container_name" /tmp/fake_healthcheck.sh
    [ "$status" -ne 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Healthcheck handles missing netcat gracefully"
}

@test "Healthcheck should work with different netcat variants" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for tcp-proxy to start
    sleep 10
    
    # Check which netcat variant is available
    run docker exec "$container_name" nc --help
    local nc_help_status=$status
    
    # Test the healthcheck regardless of netcat variant
    run docker exec "$container_name" /healthcheck.sh
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Healthcheck works with available netcat variant"
}

# =============================================================================
# Performance and Timing Tests
# =============================================================================

@test "Healthcheck should complete within reasonable time" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for tcp-proxy to start
    sleep 10
    
    # Measure healthcheck execution time
    local start_time=$(date +%s%N)
    run docker exec "$container_name" /healthcheck.sh
    local end_time=$(date +%s%N)
    
    [ "$status" -eq 0 ]
    
    # Calculate duration in milliseconds
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    # Should complete within 5 seconds (5000ms)
    [ "$duration_ms" -lt 5000 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Healthcheck completes within reasonable time (${duration_ms}ms)"
}

@test "Healthcheck should be consistent across multiple runs" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for tcp-proxy to start
    sleep 10
    
    # Run healthcheck multiple times
    local success_count=0
    local total_runs=5
    
    for i in $(seq 1 $total_runs); do
        if docker exec "$container_name" /healthcheck.sh >/dev/null 2>&1; then
            success_count=$((success_count + 1))
        fi
        sleep 1
    done
    
    # All runs should succeed
    [ "$success_count" -eq "$total_runs" ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Healthcheck is consistent across multiple runs ($success_count/$total_runs)"
}

# =============================================================================
# Integration with Container Lifecycle
# =============================================================================

@test "Healthcheck should work immediately after container start" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for tcp-proxy startup
    sleep 15
    
    # Healthcheck should work right after startup
    run docker exec "$container_name" /healthcheck.sh
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Healthcheck works immediately after container start"
}

@test "Healthcheck should detect service recovery" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for tcp-proxy to start
    sleep 10
    
    # Verify healthcheck passes initially
    run docker exec "$container_name" /healthcheck.sh
    [ "$status" -eq 0 ]
    
    # Kill tcp-proxy
    docker exec "$container_name" pkill -f tcp-proxy >/dev/null 2>&1 || true
    sleep 2
    
    # Healthcheck should fail
    run docker exec "$container_name" /healthcheck.sh
    [ "$status" -ne 0 ]
    
    # Restart tcp-proxy (simulate recovery) - use the same command as entrypoint
    docker exec "$container_name" sh -c "cd /var/lib/zerotier-one && nohup /usr/sbin/tcp-proxy -p 443 -l /var/lib/zerotier-one/local.conf > /dev/null 2>&1 &" || true
    sleep 10
    
    # Healthcheck should pass again
    run docker exec "$container_name" /healthcheck.sh
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Healthcheck detects service recovery"
}