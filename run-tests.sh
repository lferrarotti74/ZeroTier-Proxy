#!/bin/bash

# ZeroTier-Proxy Local Test Runner
# This script helps you run BATS tests locally for development and debugging

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test directories
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tests"
CONTAINER_TESTS="$TESTS_DIR/container"
SCRIPTS_TESTS="$TESTS_DIR/scripts"
SECURITY_TESTS="$TESTS_DIR/security"
COMPOSE_TESTS="$TESTS_DIR/compose"

# Docker image name
IMAGE_NAME="zerotier-proxy:test"

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  ZeroTier-Proxy Test Runner${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

print_section() {
    echo -e "${YELLOW}>>> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_prerequisites() {
    print_section "Checking prerequisites..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if BATS is available
    if ! command -v bats &> /dev/null; then
        print_error "BATS is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Docker image exists
    if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
        print_error "Docker image '$IMAGE_NAME' not found. Please build it first:"
        echo "  docker build --build-arg VERSION=1.14.2 -t $IMAGE_NAME ."
        exit 1
    fi
    
    print_success "All prerequisites met"
    echo
}

run_container_tests() {
    print_section "Running Container Tests..."
    if bats "$CONTAINER_TESTS"/*.bats; then
        print_success "Container tests passed"
    else
        print_error "Container tests failed"
        return 1
    fi
    echo
}

run_script_tests() {
    print_section "Running Script Tests..."
    if bats "$SCRIPTS_TESTS"/*.bats; then
        print_success "Script tests passed"
    else
        print_error "Script tests failed"
        return 1
    fi
    echo
}

run_security_tests() {
    print_section "Running Security Tests..."
    if bats "$SECURITY_TESTS"/*.bats; then
        print_success "Security tests passed"
    else
        print_error "Security tests failed"
        return 1
    fi
    echo
}

run_compose_tests() {
    print_section "Running Compose Tests..."
    if bats "$COMPOSE_TESTS"/*.bats; then
        print_success "Compose tests passed"
    else
        print_error "Compose tests failed"
        return 1
    fi
    echo
}

cleanup_containers() {
    print_section "Cleaning up test containers..."
    
    # Stop and remove any test containers
    docker ps -a --filter "name=zerotier-proxy-test" --format "{{.Names}}" | while read -r container; do
        if [ -n "$container" ]; then
            echo "Stopping and removing container: $container"
            docker stop "$container" 2>/dev/null || true
            docker rm "$container" 2>/dev/null || true
        fi
    done
    
    # Clean up any test networks
    docker network ls --filter "name=zerotier-test" --format "{{.Name}}" | while read -r network; do
        if [ -n "$network" ]; then
            echo "Removing network: $network"
            docker network rm "$network" 2>/dev/null || true
        fi
    done
    
    print_success "Cleanup completed"
    echo
}

show_usage() {
    echo "Usage: $0 [OPTION]"
    echo
    echo "Options:"
    echo "  all         Run all tests (default)"
    echo "  container   Run container build and deployment tests"
    echo "  scripts     Run entrypoint and healthcheck script tests"
    echo "  security    Run security validation tests"
    echo "  compose     Run Docker Compose orchestration tests"
    echo "  cleanup     Clean up test containers and networks"
    echo "  help        Show this help message"
    echo
    echo "Examples:"
    echo "  $0                    # Run all tests"
    echo "  $0 container          # Run only container tests"
    echo "  $0 scripts security   # Run scripts and security tests"
    echo "  $0 cleanup            # Clean up test resources"
}

main() {
    print_header
    
    # If no arguments provided, run all tests
    if [ $# -eq 0 ]; then
        set -- "all"
    fi
    
    # Handle help
    if [[ "$1" == "help" || "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    # Handle cleanup only
    if [[ "$1" == "cleanup" ]]; then
        cleanup_containers
        exit 0
    fi
    
    # Check prerequisites for test runs
    check_prerequisites
    
    local failed_tests=0
    
    # Process arguments
    for arg in "$@"; do
        case "$arg" in
            "all")
                run_container_tests || ((failed_tests++))
                run_script_tests || ((failed_tests++))
                run_security_tests || ((failed_tests++))
                run_compose_tests || ((failed_tests++))
                ;;
            "container")
                run_container_tests || ((failed_tests++))
                ;;
            "scripts")
                run_script_tests || ((failed_tests++))
                ;;
            "security")
                run_security_tests || ((failed_tests++))
                ;;
            "compose")
                run_compose_tests || ((failed_tests++))
                ;;
            *)
                print_error "Unknown option: $arg"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Cleanup after tests
    cleanup_containers
    
    # Final result
    echo -e "${BLUE}================================${NC}"
    if [ $failed_tests -eq 0 ]; then
        print_success "All tests completed successfully!"
        exit 0
    else
        print_error "$failed_tests test suite(s) failed"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"