#!/bin/bash

# Quick test script to verify ksr-cli functionality with the test environment
# This script runs through basic operations to ensure everything is working

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEST_DATA_DIR="$SCRIPT_DIR/test-data/schemas"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Running ksr-cli Quick Tests${NC}"
echo -e "${BLUE}===========================${NC}"
echo ""

# Function to run a test
run_test() {
    local test_name=$1
    local command=$2
    
    echo -n -e "${YELLOW}Testing ${test_name}...${NC} "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "${RED}Command: $command${NC}"
        return 1
    fi
}

# Check if test environment is running
echo -e "${YELLOW}Checking test environment...${NC}"
if ! curl -sf http://localhost:38081/subjects > /dev/null 2>&1; then
    echo -e "${RED}Error: Schema Registry is not accessible at http://localhost:38081${NC}"
    echo -e "${YELLOW}Please start the test environment first: ./tests/start-test-env.sh${NC}"
    exit 1
fi

# Configure ksr-cli
echo -e "${YELLOW}Configuring ksr-cli...${NC}"
ksr-cli config set registry-url http://localhost:38081

echo ""
echo -e "${BLUE}Running Tests:${NC}"

# Test 1: List subjects (should be empty initially)
run_test "List subjects" "ksr-cli get subjects"

# Test 2: Register user schema
run_test "Register user schema" "ksr-cli create schema user-value --file $TEST_DATA_DIR/user.avsc"

# Test 3: Register order schema
run_test "Register order schema" "ksr-cli create schema order-value --file $TEST_DATA_DIR/order.avsc"

# Test 4: List subjects again (should show both schemas)
run_test "List subjects with data" "ksr-cli get subjects | grep -E '(user-value|order-value)'"

# Test 5: Get specific schema
run_test "Get user schema" "ksr-cli get schemas user-value"

# Test 6: Get schema versions
run_test "Get schema versions" "ksr-cli get versions user-value"

# Test 7: Check compatibility
run_test "Check compatibility" "ksr-cli check compatibility user-value --file $TEST_DATA_DIR/user.avsc"

# Test 8: Get global config
run_test "Get global config" "ksr-cli get config"

# Test 9: JSON output format
run_test "JSON output format" "ksr-cli get subjects --output json"

# Test 10: YAML output format
run_test "YAML output format" "ksr-cli get subjects --output yaml"

echo ""
echo -e "${GREEN}All tests completed!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  • View schemas in AKHQ: ${YELLOW}http://localhost:38080${NC}"
echo -e "  • Run more tests: ${YELLOW}ksr-cli --help${NC}"
echo -e "  • Clean up: ${YELLOW}./tests/stop-test-env.sh${NC}"
