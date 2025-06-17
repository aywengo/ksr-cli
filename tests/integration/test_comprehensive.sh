#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Array of test suites  
TEST_SUITES=(
    "test_basic.sh"
    "test_create_commands.sh"
    "test_get_commands.sh"
    "test_check_commands.sh"
    "test_config_commands.sh"
    "test_context_operations.sh"
    "test_schema_evolution.sh"
    "test_mode_commands.sh"
    "test_export_commands.sh"
    "test_import_commands.sh"
    "test_import_export_integration.sh"
    "test_all_versions_flag.sh"
    "test_command_line_flags.sh"
    "test_flag_precedence.sh"
    "test_delete_commands.sh"
)

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  COMPREHENSIVE INTEGRATION TEST SUITE${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Function to run a test suite
run_test_suite() {
    local test_file=$1
    local suite_name=$(basename "$test_file" .sh)
    
    echo -e "${BLUE}Running test suite: ${suite_name}${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}"
    
    if bash "$test_file"; then
        echo -e "${GREEN}✓ Test suite ${suite_name} PASSED${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ Test suite ${suite_name} FAILED${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
}

# Check if CLI binary exists
CLI_BINARY="../../build/ksr-cli"
if [ ! -f "$CLI_BINARY" ]; then
    echo -e "${RED}Error: CLI binary not found at $CLI_BINARY${NC}"
    echo -e "${YELLOW}Please build the CLI first: make build${NC}"
    exit 1
fi

# Run all test suites
for test_suite in "${TEST_SUITES[@]}"; do
    if [ -f "$test_suite" ]; then
        run_test_suite "$test_suite"
    else
        echo -e "${YELLOW}Warning: Test suite $test_suite not found, skipping...${NC}"
    fi
done

# Print summary
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}              TEST SUMMARY${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "Total test suites: ${TOTAL_TESTS}"
echo -e "Passed: ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Failed: ${RED}${FAILED_TESTS}${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
    echo -e "${GREEN}Your ksr-cli implementation is working correctly!${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo -e "${YELLOW}Please review the failed test suites above and fix the issues.${NC}"
    exit 1
fi 