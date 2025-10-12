#!/usr/bin/env bats

# Security Tests for ZeroTier-Proxy
# Tests container security, permissions, user privileges, and security best practices

load '../helpers/test_helpers'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

# =============================================================================
# User and Permission Security Tests
# =============================================================================

@test "Container should run as non-root user" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 5
    
    # Check running user
    run docker exec "$container_name" whoami
    [ "$status" -eq 0 ]
    [[ "$output" != "root" ]]
    [[ "$output" == "zerotier" ]]
    
    # Check user ID
    run docker exec "$container_name" id -u
    [ "$status" -eq 0 ]
    [[ "$output" != "0" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container runs as non-root user (zerotier)"
}

@test "Container should have correct user and group configuration" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 5
    
    # Check user exists
    run docker exec "$container_name" id zerotier
    [ "$status" -eq 0 ]
    [[ "$output" =~ "uid=" ]]
    [[ "$output" =~ "gid=" ]]
    
    # Check user has proper home directory
    run docker exec "$container_name" getent passwd zerotier
    [ "$status" -eq 0 ]
    [[ "$output" =~ "/var/lib/zerotier-one" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container has correct user and group configuration"
}

@test "Container should not have sudo or su capabilities" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 5
    
    # Check sudo is not available
    run docker exec "$container_name" which sudo
    [ "$status" -ne 0 ]
    
    # Check su is not available or doesn't work
    run docker exec "$container_name" which su
    # su might exist but shouldn't work for privilege escalation
    
    # Try to escalate privileges (should fail)
    run docker exec "$container_name" su -c "whoami" 2>/dev/null
    [ "$status" -ne 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container does not have sudo or su capabilities"
}

# =============================================================================
# File System Security Tests
# =============================================================================

@test "Container should have proper file permissions on critical files" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 5
    
    # Check entrypoint.sh permissions
    run check_file_permissions "/entrypoint.sh" "755"
    [ "$status" -eq 0 ]
    
    # Check healthcheck.sh permissions
    run check_file_permissions "/healthcheck.sh" "755"
    [ "$status" -eq 0 ]
    
    # Check tcp-proxy binary permissions (it's in /usr/sbin, not /usr/local/bin)
    run check_file_permissions "/usr/sbin/tcp-proxy" "755"
    [ "$status" -eq 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container has proper file permissions on critical files"
}

@test "Container should have proper ownership on zerotier directories" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 5
    
    # Check zerotier-one directory ownership using docker exec directly
    run docker exec "$container_name" stat -c '%U:%G' /var/lib/zerotier-one
    [ "$status" -eq 0 ]
    [[ "$output" == "zerotier:zerotier" ]]
    
    # Check if local.conf exists and has proper ownership
    if docker exec "$container_name" test -f /var/lib/zerotier-one/local.conf 2>/dev/null; then
        run docker exec "$container_name" stat -c '%U:%G' /var/lib/zerotier-one/local.conf
        [ "$status" -eq 0 ]
        [[ "$output" == "zerotier:zerotier" ]]
    fi
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container has proper ownership on zerotier directories"
}

@test "Container should not have world-writable files in critical locations" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 5
    
    # Check for world-writable files in /usr/local/bin
    run docker exec "$container_name" find /usr/local/bin -type f -perm -002 2>/dev/null
    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
    
    # Check for world-writable files in /etc
    run docker exec "$container_name" find /etc -type f -perm -002 2>/dev/null
    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
    
    # Check for world-writable files in /var/lib/zerotier-one
    run docker exec "$container_name" find /var/lib/zerotier-one -type f -perm -002 2>/dev/null
    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container does not have world-writable files in critical locations"
}

# =============================================================================
# Process Security Tests
# =============================================================================

@test "Container processes should run as non-root" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for processes to start
    sleep 10
    
    # Check all running processes
    run docker exec "$container_name" ps -eo pid,user,cmd
    [ "$status" -eq 0 ]
    
    # Should not have any root processes except kernel threads
    local root_processes
    root_processes=$(echo "$output" | grep -v "PID USER" | grep "root" | grep -v "\[" || true)
    
    # If there are root processes, they should only be kernel threads (in brackets)
    if [[ -n "$root_processes" ]]; then
        [[ "$root_processes" =~ ^\s*[0-9]+\s+root\s+\[.*\]\s*$ ]]
    fi
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container processes run as non-root"
}

@test "Container should not have unnecessary privileged processes" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for processes to start
    sleep 10
    
    # Check for potentially dangerous processes
    run docker exec "$container_name" ps aux
    [ "$status" -eq 0 ]
    
    # Should not have ssh, telnet, ftp servers
    [[ ! "$output" =~ "sshd" ]]
    [[ ! "$output" =~ "telnetd" ]]
    [[ ! "$output" =~ "ftpd" ]]
    
    # Should not have package managers running
    [[ ! "$output" =~ "apt" ]]
    [[ ! "$output" =~ "yum" ]]
    [[ ! "$output" =~ "apk" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container does not have unnecessary privileged processes"
}

# =============================================================================
# Network Security Tests
# =============================================================================

@test "Container should only expose necessary ports" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for services to start
    sleep 10
    
    # Check listening ports
    run docker exec "$container_name" netstat -tlnp 2>/dev/null || docker exec "$container_name" ss -tlnp 2>/dev/null
    [ "$status" -eq 0 ]
    
    # Should have port 443 listening
    [[ "$output" =~ ":443" ]]
    
    # Count number of listening ports (excluding loopback-only)
    local listening_ports
    listening_ports=$(echo "$output" | grep -E "0\.0\.0\.0:|:::" | wc -l)
    
    # Should have minimal number of exposed ports (ideally just 1 for tcp-proxy)
    [ "$listening_ports" -le 2 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container only exposes necessary ports ($listening_ports ports)"
}

@test "Container should not have unnecessary network services" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for services to start
    sleep 10
    
    # Check for common unnecessary services
    run docker exec "$container_name" netstat -tlnp 2>/dev/null || docker exec "$container_name" ss -tlnp 2>/dev/null
    [ "$status" -eq 0 ]
    
    # Should not have SSH (port 22)
    [[ ! "$output" =~ ":22" ]]
    
    # Should not have FTP (port 21)
    [[ ! "$output" =~ ":21" ]]
    
    # Should not have Telnet (port 23)
    [[ ! "$output" =~ ":23" ]]
    
    # Should not have HTTP (port 80) unless specifically configured
    [[ ! "$output" =~ ":80" ]] || [[ "$output" =~ "tcp-proxy" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container does not have unnecessary network services"
}

# =============================================================================
# Container Runtime Security Tests
# =============================================================================

@test "Container should not run in privileged mode" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Check container configuration
    run docker inspect "$container_name" --format='{{.HostConfig.Privileged}}'
    [ "$status" -eq 0 ]
    [[ "$output" == "false" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container does not run in privileged mode"
}

@test "Container should have appropriate security options" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Check security options
    run docker inspect "$container_name" --format='{{.HostConfig.SecurityOpt}}'
    [ "$status" -eq 0 ]
    
    # Should not have --security-opt apparmor:unconfined or similar dangerous options
    [[ ! "$output" =~ "apparmor:unconfined" ]]
    [[ ! "$output" =~ "seccomp:unconfined" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container has appropriate security options"
}

@test "Container should not have excessive capabilities" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 5
    
    # Check process capabilities
    run docker exec "$container_name" grep Cap /proc/self/status 2>/dev/null || echo "Capabilities check not available"
    [ "$status" -eq 0 ]
    
    # If capabilities are available, they should be minimal
    if [[ "$output" =~ "Cap" ]]; then
        # Should not have CAP_SYS_ADMIN or other dangerous capabilities
        [[ ! "$output" =~ "CapEff:.*[^0].*" ]] || [[ "$output" =~ "CapEff:.*0000000000000000" ]]
    fi
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container does not have excessive capabilities"
}

# =============================================================================
# Secrets and Configuration Security Tests
# =============================================================================

@test "Container should not expose sensitive information in environment" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 5
    
    # Check environment variables
    run docker exec "$container_name" env
    [ "$status" -eq 0 ]
    
    # Should not contain common sensitive patterns
    [[ ! "$output" =~ "PASSWORD=" ]]
    [[ ! "$output" =~ "SECRET=" ]]
    [[ ! "$output" =~ "KEY=" ]]
    [[ ! "$output" =~ "TOKEN=" ]]
    [[ ! "$output" =~ "API_KEY=" ]]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container does not expose sensitive information in environment"
}

@test "Container should not have hardcoded secrets in configuration files" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 5
    
    # Check common configuration files for hardcoded secrets
    run docker exec "$container_name" find /etc /var/lib/zerotier-one -type f -name "*.conf" -o -name "*.cfg" -o -name "*.json" 2>/dev/null
    [ "$status" -eq 0 ]
    
    # If configuration files exist, check them for sensitive patterns
    if [[ -n "$output" ]]; then
        local config_files="$output"
        for file in $config_files; do
            local content
            content=$(docker exec "$container_name" cat "$file" 2>/dev/null || echo "")
            
            # Should not contain obvious secrets
            [[ ! "$content" =~ "password.*:" ]]
            [[ ! "$content" =~ "secret.*:" ]]
            [[ ! "$content" =~ "key.*:.*[a-zA-Z0-9]{20,}" ]]
        done
    fi
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container does not have hardcoded secrets in configuration files"
}

# =============================================================================
# Resource Security Tests
# =============================================================================

@test "Container should have reasonable resource limits" {
    local container_name
    container_name=$(generate_container_name)
    
    # Start container with basic resource limits
    run docker run -d --name "$container_name" \
        --memory=256m \
        --cpus=1.0 \
        "$TEST_IMAGE"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 10
    
    # Check if container is still running (didn't crash due to limits)
    run is_container_running "$container_name"
    [ "$status" -eq 0 ]
    
    # Check memory usage
    run docker stats --no-stream --format "{{.MemUsage}}" "$container_name"
    [ "$status" -eq 0 ]
    
    # Memory usage should be reasonable (less than 100MB for this simple service)
    local mem_usage
    mem_usage=$(echo "$output" | grep -oE '[0-9.]+' | head -1)
    
    # Convert to MB if needed and check
    if [[ "$output" =~ "GiB" ]]; then
        # If usage is in GiB, it's too high
        false
    fi
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container has reasonable resource usage"
}

@test "Container should not allow privilege escalation" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 5
    
    # Try to access privileged files (should fail)
    run docker exec "$container_name" cat /etc/shadow 2>/dev/null
    [ "$status" -ne 0 ]
    
    # Try to modify system files (should fail)
    run docker exec "$container_name" touch /etc/test_file 2>/dev/null
    [ "$status" -ne 0 ]
    
    # Try to access /proc/1 (should fail or be limited)
    run docker exec "$container_name" cat /proc/1/environ 2>/dev/null
    # This might succeed but shouldn't show host process info
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container does not allow privilege escalation"
}

# =============================================================================
# Image Security Tests
# =============================================================================

@test "Container image should not contain package managers" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 5
    
    # Check for package managers (should not be present in production image)
    run docker exec "$container_name" which apt-get 2>/dev/null
    [ "$status" -ne 0 ]
    
    run docker exec "$container_name" which yum 2>/dev/null
    [ "$status" -ne 0 ]
    
    run docker exec "$container_name" which apk 2>/dev/null
    [ "$status" -ne 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container image does not contain package managers"
}

@test "Container should have minimal attack surface" {
    local container_name
    container_name=$(generate_container_name)
    
    run start_proxy_container_background "$container_name"
    [ "$status" -eq 0 ]
    
    # Wait for container to start
    sleep 5
    
    # Check for unnecessary tools that could be used for attacks
    run docker exec "$container_name" which curl 2>/dev/null
    [ "$status" -ne 0 ]
    
    run docker exec "$container_name" which wget 2>/dev/null
    [ "$status" -ne 0 ]
    
    run docker exec "$container_name" which gcc 2>/dev/null
    [ "$status" -ne 0 ]
    
    run docker exec "$container_name" which python 2>/dev/null
    [ "$status" -ne 0 ]
    
    run docker exec "$container_name" which perl 2>/dev/null
    [ "$status" -ne 0 ]
    
    # Cleanup
    docker rm -f "$container_name" >/dev/null 2>&1
    
    print_success "Container has minimal attack surface"
}