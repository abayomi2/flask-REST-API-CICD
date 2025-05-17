#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# The base URL of the application will be passed as the first argument to this script
APP_BASE_URL="$1"

if [ -z "$APP_BASE_URL" ]; then
    echo "ERROR: Application base URL not provided."
    exit 1
fi

# Add http:// if not present (simple check)
if [[ ! "$APP_BASE_URL" == http* ]]; then
    APP_BASE_URL="http://${APP_BASE_URL}"
fi

echo "Smoke Test Target: ${APP_BASE_URL}"

# Define endpoints to test and their expected HTTP status codes
declare -A ENDPOINTS_TO_TEST=(
    ["/"]=200
    ["/api/v1/health"]=200
    ["/api/v1/devices/user123"]=200
    ["/api/v1/devices/laptop001/status"]=200
    ["/api/v1/devices/nonexistentuser12345"]=404 # Test a 404 case
    ["/metrics"]=200 # Check the Prometheus metrics endpoint
)

# --- Helper Function to Test an Endpoint ---
test_endpoint() {
    local endpoint=$1
    local expected_status=$2
    local full_url="${APP_BASE_URL}${endpoint}"
    local attempt_num=0
    local max_attempts=5 # Try a few times for services that might be slow to come up fully
    local delay_seconds=10

    echo -n "Testing endpoint: ${full_url} ... "

    while [ $attempt_num -lt $max_attempts ]; do
        attempt_num=$((attempt_num + 1))
        # -s: silent, -o /dev/null: discard output, -w "%{http_code}": write only HTTP status code
        # --connect-timeout 5: max time to connect
        # --max-time 10: max total time for operation
        http_status=$(curl --connect-timeout 5 --max-time 10 -s -o /dev/null -w "%{http_code}" "${full_url}")

        if [ "$http_status" -eq "$expected_status" ]; then
            echo "SUCCESS (Status: ${http_status})"
            return 0 # Success
        fi
        
        if [ $attempt_num -lt $max_attempts ]; then
            echo "Attempt ${attempt_num} FAILED (Status: ${http_status}, Expected: ${expected_status}). Retrying in ${delay_seconds}s..."
            sleep $delay_seconds
        else
            echo "FAILED (Status: ${http_status}, Expected: ${expected_status}) after ${max_attempts} attempts."
            return 1 # Failure
        fi
    done
}

# --- Run Tests ---
all_tests_passed=true

for endpoint in "${!ENDPOINTS_TO_TEST[@]}"; do
    expected_status=${ENDPOINTS_TO_TEST[$endpoint]}
    if ! test_endpoint "$endpoint" "$expected_status"; then
        all_tests_passed=false
    fi
done

# --- Final Result ---
if [ "$all_tests_passed" = true ]; then
    echo "-------------------------------------"
    echo "All smoke tests PASSED!"
    echo "-------------------------------------"
    exit 0
else
    echo "-------------------------------------"
    echo "One or more smoke tests FAILED!"
    echo "-------------------------------------"
    exit 1
fi