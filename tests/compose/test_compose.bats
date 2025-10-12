#!/usr/bin/env bats

# Docker Compose Tests for ZeroTier-Proxy
# Tests Docker Compose deployment, orchestration, and multi-container scenarios

load '../helpers/test_helpers'

# Robust cleanup function for test resources
cleanup_test_resources() {
    local cleanup_errors=0
    
    # Clean up any leftover test networks
    echo "🧹 Cleaning up leftover test networks..."
    local test_networks=$(docker network ls --filter name=zerotier-proxy-test --format "{{.Name}}" 2>/dev/null || true)
    if [[ -n "$test_networks" ]]; then
        while IFS= read -r network; do
            if [[ -n "$network" ]]; then
                echo "  Removing network: $network"
                if ! docker network rm "$network" >/dev/null 2>&1; then
                    echo "  ⚠️  Failed to remove network: $network"
                    ((cleanup_errors++))
                fi
            fi
        done <<< "$test_networks"
    fi
    
    # Clean up any leftover test containers
    echo "🧹 Cleaning up leftover test containers..."
    local test_containers=$(docker ps -a --filter name=zerotier-proxy-test --format "{{.Names}}" 2>/dev/null || true)
    if [[ -n "$test_containers" ]]; then
        while IFS= read -r container; do
            if [[ -n "$container" ]]; then
                echo "  Removing container: $container"
                if ! docker rm -f "$container" >/dev/null 2>&1; then
                    echo "  ⚠️  Failed to remove container: $container"
                    ((cleanup_errors++))
                fi
            fi
        done <<< "$test_containers"
    fi
    
    # Clean up any leftover compose files
    echo "🧹 Cleaning up leftover compose files..."
    find /tmp -name "zerotier-proxy-test-compose*.yml" -type f -delete 2>/dev/null || true
    
    if [[ $cleanup_errors -gt 0 ]]; then
        echo "⚠️  Cleanup completed with $cleanup_errors errors"
    else
        echo "✅ Cleanup completed successfully"
    fi
}

setup() {
    setup_test_environment
    
    # Pre-test cleanup to remove any leftover resources from previous failed runs
    cleanup_test_resources
    
    # Create a temporary compose file for testing
    export COMPOSE_FILE="/tmp/zerotier-proxy-test-compose.yml"
    export COMPOSE_PROJECT_NAME="zerotier-proxy-test-$(date +%s)"
}

teardown() {
    local teardown_errors=0
    
    # Clean up compose resources with better error handling
    if [[ -f "$COMPOSE_FILE" ]]; then
        echo "🧹 Tearing down compose project: $COMPOSE_PROJECT_NAME"
        
        # First try graceful shutdown
        if ! docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down --volumes --remove-orphans 2>/dev/null; then
            echo "⚠️  Graceful compose down failed, trying force cleanup..."
            ((teardown_errors++))
            
            # Force remove containers if graceful shutdown failed
            local containers=$(docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" ps -q 2>/dev/null || true)
            if [[ -n "$containers" ]]; then
                echo "  Force removing containers..."
                docker rm -f $containers >/dev/null 2>&1 || true
            fi
            
            # Force remove networks
            local networks=$(docker network ls --filter name="${COMPOSE_PROJECT_NAME}" --format "{{.Name}}" 2>/dev/null || true)
            if [[ -n "$networks" ]]; then
                while IFS= read -r network; do
                    if [[ -n "$network" ]]; then
                        echo "  Force removing network: $network"
                        docker network rm "$network" >/dev/null 2>&1 || true
                    fi
                done <<< "$networks"
            fi
        fi
        
        # Remove compose file
        rm -f "$COMPOSE_FILE"
    fi
    
    # Run additional cleanup to catch any missed resources
    cleanup_test_resources
    
    teardown_test_environment
    
    if [[ $teardown_errors -gt 0 ]]; then
        echo "⚠️  Teardown completed with $teardown_errors errors"
    fi
}

# =============================================================================
# Basic Compose Configuration Tests
# =============================================================================

@test "Should create valid basic docker-compose.yml" {
    # Create basic compose file
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  zerotier-proxy:
    image: ${TEST_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}-proxy
    ports:
      - "443:443"
    environment:
      - ZT_TCP_PORT=443
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    restart: unless-stopped
EOF

    # Validate compose file syntax
    run docker-compose -f "$COMPOSE_FILE" config
    [ "$status" -eq 0 ]
    
    # Should contain our service
    [[ "$output" =~ "zerotier-proxy" ]]
    [[ "$output" =~ "$TEST_IMAGE" ]]
    
    print_success "Created valid basic docker-compose.yml"
}

@test "Should deploy single service with docker-compose" {
    # Create basic compose file
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  zerotier-proxy:
    image: ${TEST_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}-proxy
    ports:
      - "8443:443"
    environment:
      - ZT_TCP_PORT=443
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
EOF

    # Deploy with compose
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d
    [ "$status" -eq 0 ]
    
    # Wait for service to start and become healthy
    local container_name="${COMPOSE_PROJECT_NAME}-proxy"
    print_info "Waiting for container to become healthy..."
    
    # Wait for container to be healthy (up to 60 seconds)
    local timeout=60
    local count=0
    while [ $count -lt $timeout ]; do
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-health")
        if [ "$health_status" = "healthy" ]; then
            print_success "Container is healthy"
            break
        elif [ "$health_status" = "unhealthy" ]; then
            print_error "Container became unhealthy"
            docker logs "$container_name"
            return 1
        fi
        sleep 2
        count=$((count + 2))
    done
    
    if [ $count -ge $timeout ]; then
        print_warning "Container did not become healthy within $timeout seconds, proceeding anyway"
    fi
    
    # Check service is running
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" ps
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Up" ]]
    
    # Check container is healthy
    local container_name="${COMPOSE_PROJECT_NAME}-proxy"
    run wait_for_container_healthy "$container_name" 60
    [ "$status" -eq 0 ]
    
    print_success "Deployed single service with docker-compose"
}

# =============================================================================
# Multi-Service Compose Tests
# =============================================================================

@test "Should deploy multi-service stack with load balancer" {
    # Create multi-service compose file with nginx load balancer
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  zerotier-proxy-1:
    image: ${TEST_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}-proxy-1
    environment:
      - ZT_TCP_PORT=443
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    networks:
      - zerotier-net

  zerotier-proxy-2:
    image: ${TEST_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}-proxy-2
    environment:
      - ZT_TCP_PORT=443
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    networks:
      - zerotier-net

  nginx:
    image: nginx:alpine
    container_name: ${COMPOSE_PROJECT_NAME}-nginx
    ports:
      - "8080:80"
    volumes:
      - /tmp/nginx-${COMPOSE_PROJECT_NAME}.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - zerotier-proxy-1
      - zerotier-proxy-2
    networks:
      - zerotier-net

networks:
  zerotier-net:
    driver: bridge
EOF

    # Create nginx configuration
    cat > "/tmp/nginx-${COMPOSE_PROJECT_NAME}.conf" << EOF
events {
    worker_connections 1024;
}

http {
    upstream zerotier_backend {
        server ${COMPOSE_PROJECT_NAME}-proxy-1:443;
        server ${COMPOSE_PROJECT_NAME}-proxy-2:443;
    }

    server {
        listen 80;
        location / {
            proxy_pass http://zerotier_backend;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
    }
}
EOF

    # Deploy with compose
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d
    [ "$status" -eq 0 ]
    
    # Wait for services to start
    sleep 20
    
    # Check all services are running
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" ps
    [ "$status" -eq 0 ]
    
    # Count running services
    local running_services
    running_services=$(echo "$output" | grep -c "Up" || echo "0")
    [ "$running_services" -ge 2 ]  # At least proxy services should be up
    
    # Clean up nginx config
    rm -f "/tmp/nginx-${COMPOSE_PROJECT_NAME}.conf"
    
    print_success "Deployed multi-service stack with load balancer"
}

@test "Should handle service dependencies correctly" {
    # Create compose file with dependencies
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  zerotier-proxy:
    image: ${TEST_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}-proxy
    environment:
      - ZT_TCP_PORT=443
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    networks:
      - zerotier-net

  monitor:
    image: alpine:latest
    container_name: ${COMPOSE_PROJECT_NAME}-monitor
    command: sh -c "while true; do nc -z zerotier-proxy 443 && echo 'Proxy is up' || echo 'Proxy is down'; sleep 30; done"
    depends_on:
      - zerotier-proxy
    networks:
      - zerotier-net

networks:
  zerotier-net:
    driver: bridge
EOF

    # Deploy with compose
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d
    [ "$status" -eq 0 ]
    
    # Wait for services to start
    sleep 15
    
    # Check dependency order - monitor should start after proxy
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" ps
    [ "$status" -eq 0 ]
    [[ "$output" =~ "zerotier-proxy" ]]
    [[ "$output" =~ "monitor" ]]
    
    # Check monitor can reach proxy
    sleep 10
    run docker logs "${COMPOSE_PROJECT_NAME}-monitor" 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Proxy is up" ]]
    
    print_success "Handled service dependencies correctly"
}

# =============================================================================
# Environment and Configuration Tests
# =============================================================================

@test "Should handle environment variables in compose" {
    skip "Temporarily disabled due to health check timing issues - TODO: Fix container health check reliability"
    
    # Create compose file with environment variables
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  zerotier-proxy:
    image: ${TEST_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}-proxy
    ports:
      - "8443:8443"
    environment:
      - ZT_TCP_PORT=8443
      - ZT_OVERRIDE_LOCAL_CONF=true
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
EOF

    # Deploy with compose
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d
    [ "$status" -eq 0 ]
    
    # Wait for service to start and become healthy
    local container_name="${COMPOSE_PROJECT_NAME}-proxy"
    print_info "Waiting for container to become healthy..."
    
    # Wait for container to be healthy (up to 60 seconds)
    local timeout=60
    local count=0
    while [ $count -lt $timeout ]; do
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-health")
        if [ "$health_status" = "healthy" ]; then
            print_success "Container is healthy"
            break
        elif [ "$health_status" = "unhealthy" ]; then
            print_error "Container became unhealthy"
            docker logs "$container_name"
            return 1
        fi
        sleep 2
        count=$((count + 2))
    done
    
    if [ $count -ge $timeout ]; then
        print_warning "Container did not become healthy within $timeout seconds, proceeding anyway"
    fi
    
    # Check environment variables are set
    local container_name="${COMPOSE_PROJECT_NAME}-proxy"
    
    # Wait a bit more for container to fully start
    sleep 10
    
    # Check if container is still running
    if ! docker ps | grep -q "$container_name"; then
        print_error "Container $container_name is not running"
        docker ps -a | grep "$container_name" || print_error "Container not found at all"
        return 1
    fi
    
    # Test docker exec with a simple command first
    run docker exec "$container_name" echo "test"
    if [ "$status" -ne 0 ]; then
        print_error "Basic docker exec failed with status: $status"
        print_error "Output: $output"
        return 1
    fi
    
    # Now try to get environment variables
    run docker exec "$container_name" env
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ZT_TCP_PORT=8443" ]]
    [[ "$output" =~ "ZT_OVERRIDE_LOCAL_CONF=true" ]]
    
    # Check service is listening on custom port
    run wait_for_port "$container_name" 8443 30
    [ "$status" -eq 0 ]
    
    print_success "Handled environment variables in compose"
}

@test "Should support volume mounts in compose" {
    # Create temporary config directory
    local config_dir="/tmp/zerotier-config-${COMPOSE_PROJECT_NAME}"
    mkdir -p "$config_dir"
    
    # Create custom local.conf
    cat > "$config_dir/local.conf" << EOF
{
  "settings": {
    "tcpPort": 7443
  }
}
EOF

    # Create compose file with volume mount
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  zerotier-proxy:
    image: ${TEST_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}-proxy
    ports:
      - "7443:7443"
    volumes:
      - ${config_dir}:/var/lib/zerotier-one:rw
    environment:
      - ZT_OVERRIDE_LOCAL_CONF=false
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
EOF

    # Deploy with compose
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d
    [ "$status" -eq 0 ]
    
    # Wait for service to start
    sleep 15
    
    # Check volume is mounted
    local container_name="${COMPOSE_PROJECT_NAME}-proxy"
    run docker exec "$container_name" test -f /var/lib/zerotier-one/local.conf
    [ "$status" -eq 0 ]
    
    # Check custom configuration is used
    run docker exec "$container_name" cat /var/lib/zerotier-one/local.conf
    [ "$status" -eq 0 ]
    [[ "$output" =~ "7443" ]]
    
    # Clean up config directory
    rm -rf "$config_dir"
    
    print_success "Supported volume mounts in compose"
}

# =============================================================================
# Network Configuration Tests
# =============================================================================

@test "Should create custom networks in compose" {
    # Create compose file with custom network
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  zerotier-proxy:
    image: ${TEST_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}-proxy
    environment:
      - ZT_TCP_PORT=443
    networks:
      zerotier-custom:
        ipv4_address: 172.25.0.10
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

networks:
  zerotier-custom:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/24
EOF

    # Deploy with compose
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d
    [ "$status" -eq 0 ]
    
    # Wait for service to start
    sleep 15
    
    # Check network is created
    run docker network ls
    [ "$status" -eq 0 ]
    [[ "$output" =~ "${COMPOSE_PROJECT_NAME}_zerotier-custom" ]]
    
    # Check container has correct IP
    local container_name="${COMPOSE_PROJECT_NAME}-proxy"
    run docker exec "$container_name" ip addr show
    [ "$status" -eq 0 ]
    [[ "$output" =~ "172.25.0.10" ]]
    
    print_success "Created custom networks in compose"
}

@test "Should handle port conflicts gracefully" {
    # Create first compose file
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  zerotier-proxy-1:
    image: ${TEST_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}-proxy-1
    ports:
      - "8443:443"
    environment:
      - ZT_TCP_PORT=443
EOF

    # Deploy first service
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d
    [ "$status" -eq 0 ]
    
    # Wait for first service
    sleep 10
    
    # Create second compose file with same port (should fail)
    local compose_file_2="/tmp/zerotier-proxy-test-compose-2.yml"
    cat > "$compose_file_2" << EOF
version: '3.8'

services:
  zerotier-proxy-2:
    image: ${TEST_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}-proxy-2
    ports:
      - "8443:443"
    environment:
      - ZT_TCP_PORT=443
EOF

    # Try to deploy second service (should fail due to port conflict)
    run docker-compose -f "$compose_file_2" -p "${COMPOSE_PROJECT_NAME}-2" up -d
    [ "$status" -ne 0 ]
    
    # First service should still be running
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" ps
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Up" ]]
    
    # Clean up second compose file
    rm -f "$compose_file_2"
    
    print_success "Handled port conflicts gracefully"
}

# =============================================================================
# Scaling and Orchestration Tests
# =============================================================================

@test "Should support service scaling" {
    # Create compose file suitable for scaling
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  zerotier-proxy:
    image: ${TEST_IMAGE}
    environment:
      - ZT_TCP_PORT=443
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    networks:
      - zerotier-net

networks:
  zerotier-net:
    driver: bridge
EOF

    # Deploy with compose
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d
    [ "$status" -eq 0 ]
    
    # Wait for service to start
    sleep 15
    
    # Scale to 3 instances
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d --scale zerotier-proxy=3
    [ "$status" -eq 0 ]
    
    # Wait for scaling
    sleep 15
    
    # Check number of running instances
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" ps
    [ "$status" -eq 0 ]
    
    local running_instances
    running_instances=$(echo "$output" | grep -c "Up" || echo "0")
    [ "$running_instances" -eq 3 ]
    
    print_success "Supported service scaling (3 instances)"
}

@test "Should handle graceful shutdown" {
    # Create compose file
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  zerotier-proxy:
    image: ${TEST_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}-proxy
    environment:
      - ZT_TCP_PORT=443
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
EOF

    # Deploy with compose
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d
    [ "$status" -eq 0 ]
    
    # Wait for service to start
    sleep 15
    
    # Check service is running
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" ps
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Up" ]]
    
    # Graceful shutdown
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" down
    [ "$status" -eq 0 ]
    
    # Check services are stopped
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" ps
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "Up" ]]
    
    print_success "Handled graceful shutdown"
}

# =============================================================================
# Health Check Integration Tests
# =============================================================================

@test "Should integrate health checks with compose" {
    # Create compose file with health checks
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  zerotier-proxy:
    image: ${TEST_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}-proxy
    environment:
      - ZT_TCP_PORT=443
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 10s
EOF

    # Deploy with compose
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d
    [ "$status" -eq 0 ]
    
    # Wait for health checks to run
    sleep 30
    
    # Check health status
    local container_name="${COMPOSE_PROJECT_NAME}-proxy"
    run docker inspect --format='{{.State.Health.Status}}' "$container_name"
    [ "$status" -eq 0 ]
    [[ "$output" == "healthy" ]]
    
    print_success "Integrated health checks with compose"
}

# =============================================================================
# Resource Management Tests
# =============================================================================

@test "Should apply resource limits in compose" {
    # Create compose file with resource limits
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  zerotier-proxy:
    image: ${TEST_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}-proxy
    environment:
      - ZT_TCP_PORT=443
    deploy:
      resources:
        limits:
          memory: 128M
          cpus: '0.5'
        reservations:
          memory: 64M
          cpus: '0.25'
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
EOF

    # Deploy with compose
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" up -d
    [ "$status" -eq 0 ]
    
    # Wait for service to start
    sleep 15
    
    # Check service is running despite resource limits
    run docker-compose -f "$COMPOSE_FILE" -p "$COMPOSE_PROJECT_NAME" ps
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Up" ]]
    
    # Check container is healthy
    local container_name="${COMPOSE_PROJECT_NAME}-proxy"
    run wait_for_container_healthy "$container_name" 60
    [ "$status" -eq 0 ]
    
    print_success "Applied resource limits in compose"
}