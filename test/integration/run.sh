#!/bin/bash

# Integration test for Nibiru static file serving

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$TEST_DIR"
STATIC_DIR="$TEST_DIR/static"
PID_FILE="$TEST_DIR/nibiru_test.pid"

# Function to print test result
print_result() {
    local test_name=$1
    local result=$2
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}PASS${NC}: $test_name"
    else
        echo -e "${RED}FAIL${NC}: $test_name"
        echo "$result"
    fi
}

# Function to start server
start_server() {
    echo "Starting Nibiru server..."
    cd "$TEST_DIR/../.."  # Go to root
    ./nibiru run docs.app:app 8081 2>&1 &
    echo $! > "$PID_FILE"
    sleep 5 # Wait for server to start
}

# Function to stop server
stop_server() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    # Kill any leftover processes
    kill_leftover_processes >/dev/null 2>&1 || true
    # Clean up socket files
    rm -f /tmp/nibiru_static_*.sock 2>/dev/null || true
}

# Function to make HTTP request and check response
check_response() {
    local url=$1
    local expected_status=$2
    local expected_content=$3
    local test_name=$4

    local response
    response=$(curl -s --max-time 5 -w "HTTPSTATUS:%{http_code};" "$url" 2>/dev/null || echo "FAILED")

    if [[ "$response" == "FAILED" ]]; then
        print_result "$test_name" "Connection failed or timeout"
        return 1
    fi

    local http_code
    http_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://' -e 's/;.*//')
    local body
    body=$(echo "$response" | sed -e 's/HTTPSTATUS.*//')

    if [ "$http_code" != "$expected_status" ]; then
        print_result "$test_name" "Expected status $expected_status, got $http_code (body: '$body')"
        return 1
    fi

    if [ -n "$expected_content" ] && [[ "$body" != *"$expected_content"* ]]; then
        print_result "$test_name" "Expected content not found in response (body: '$body')"
        return 1
    fi

    print_result "$test_name" "PASS"
    return 0
}

# Trap to ensure cleanup
trap 'stop_server; kill_leftover_processes >/dev/null 2>&1 || true' EXIT

# Function to check for existing nibiru processes
check_existing_processes() {
    local existing_pids
    existing_pids=$(ps -o pid,comm | awk '$2 == "nibiru" {print $1}')
    if [ -n "$existing_pids" ]; then
        echo "ERROR: Found existing nibiru processes: $existing_pids"
        echo "Please clean up before running tests"
        return 1
    fi
    return 0
}

# Function to kill leftover processes
kill_leftover_processes() {
    local leftover_pids
    leftover_pids=$(ps -o pid,comm | awk '$2 == "nibiru" {print $1}')
    if [ -n "$leftover_pids" ]; then
        echo "WARNING: Found leftover nibiru processes: $leftover_pids"
        echo "Killing them..."
        echo "$leftover_pids" | xargs kill -9 2>/dev/null || true
        return 1
    fi
    return 0
}

# Main test
echo "Running Nibiru integration tests..."

# Check for existing processes
check_existing_processes || exit 1

# Ensure nibiru is built
echo "Building nibiru..."
cd "$TEST_DIR/../.." && make build || { echo "Build failed"; exit 1; }
cd "$APP_DIR"

start_server

echo "Server started, waiting for it to be ready..."
sleep 5

echo "Running tests..."

# Test 1: App endpoint
check_response "http://127.0.0.1:8081/" "200" "Nibiru Docs" "App endpoint"

# Test 2: Static file serving
check_response "http://127.0.0.1:8081/static/test.js" "200" "console.log" "Static JS file"

echo "Integration tests completed."

# Check for leftover processes
if ! kill_leftover_processes; then
    echo "ERROR: Leftover processes were found and killed"
    exit 1
fi

# Check if server is still running
if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Server is still running"
else
    echo "Server has exited"
fi

stop_server