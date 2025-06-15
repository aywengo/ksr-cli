#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$ROOT_DIR/tests"
INTEGRATION_DIR="$TESTS_DIR/integration"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=======================================${NC}"
echo -e "${CYAN}   KSR-CLI IMPORT/EXPORT TEST RUNNER${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Import/Export specific test suites
IMPORT_EXPORT_TESTS=(
    "test_export_commands.sh"
    "test_import_commands.sh"
    "test_import_export_integration.sh"
    "test_all_versions_flag.sh"
)

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

# 1. Build ksr-cli
cd "$ROOT_DIR"
echo -e "${BLUE}[INFO] Building ksr-cli...${NC}"
if make build > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

# 2. Check if we need to start test environment
echo -e "${BLUE}[INFO] Checking test environment...${NC}"
cd "$TESTS_DIR"

# Check if Schema Registry is accessible
if curl -s http://localhost:38081/subjects > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Test environment is running${NC}"
    USE_EXISTING_ENV=true
else
    echo -e "${YELLOW}! Test environment not detected${NC}"
    echo -e "${BLUE}[INFO] Starting test environment...${NC}"
    
    # Start docker-compose environment
    docker-compose up -d --remove-orphans
    
    # Wait for services to be healthy
    echo -e "${BLUE}[INFO] Waiting for services to be healthy...${NC}"
    ATTEMPTS=30
    while [ $ATTEMPTS -gt 0 ]; do
        HEALTHY_SERVICES=$(docker-compose ps | grep -c "healthy" || true)
        if [ "$HEALTHY_SERVICES" -ge 2 ]; then
            echo -e "${GREEN}✓ Services are healthy${NC}"
            break
        fi
        echo -n "."
        sleep 2
        ATTEMPTS=$((ATTEMPTS-1))
    done
    
    if [ $ATTEMPTS -eq 0 ]; then
        echo -e "${RED}✗ Services did not become healthy in time${NC}"
        docker-compose down --remove-orphans
        exit 1
    fi
    
    USE_EXISTING_ENV=false
fi

# 3. Configure ksr-cli
echo -e "${BLUE}[INFO] Configuring ksr-cli for test environment...${NC}"
"$ROOT_DIR/build/ksr-cli" config init > /dev/null 2>&1 || true
"$ROOT_DIR/build/ksr-cli" config set registry-url http://localhost:38081

# 4. Load initial test schemas if environment was just started
if [ "$USE_EXISTING_ENV" = "false" ]; then
    echo -e "${BLUE}[INFO] Registering initial test schemas...${NC}"
    SCHEMA_COUNT=0
    SCHEMAS_DIR="$TESTS_DIR/test-data/schemas"
    
    for schema in "$SCHEMAS_DIR"/*.avsc; do
        if [ -f "$schema" ]; then
            subject="$(basename "$schema" .avsc)-value"
            echo -e "${YELLOW}  Registering $schema as subject $subject...${NC}"
            if "$ROOT_DIR/build/ksr-cli" create schema "$subject" --file "$schema" > /dev/null 2>&1; then
                SCHEMA_COUNT=$((SCHEMA_COUNT + 1))
            else
                echo -e "${YELLOW}    Warning: Failed to register $schema${NC}"
            fi
        fi
    done
    echo -e "${GREEN}✓ Registered $SCHEMA_COUNT schemas${NC}"
fi

# 5. Run import/export specific tests
cd "$INTEGRATION_DIR"
echo -e "${BLUE}[INFO] Running import/export tests...${NC}"
echo ""

for test_suite in "${IMPORT_EXPORT_TESTS[@]}"; do
    if [ -f "$test_suite" ]; then
        run_test_suite "$test_suite"
    else
        echo -e "${YELLOW}Warning: Test suite $test_suite not found, skipping...${NC}"
    fi
done

# 6. Cleanup if we started the environment
if [ "$USE_EXISTING_ENV" = "false" ]; then
    echo -e "${BLUE}[INFO] Tearing down test environment...${NC}"
    cd "$TESTS_DIR"
    docker-compose down --remove-orphans > /dev/null 2>&1
fi

# Print summary
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}        IMPORT/EXPORT TEST SUMMARY${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "Total test suites: ${TOTAL_TESTS}"
echo -e "Passed: ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Failed: ${RED}${FAILED_TESTS}${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL IMPORT/EXPORT TESTS PASSED! 🎉${NC}"
    echo -e "${GREEN}Your import/export functionality is working correctly!${NC}"
    echo ""
    echo -e "${CYAN}Test Coverage:${NC}"
    echo -e "${CYAN}  ✓ Export commands (subjects, subject, flags, formats)${NC}"
    echo -e "${CYAN}  ✓ Import commands (subjects, subject, dry-run, error handling)${NC}"
    echo -e "${CYAN}  ✓ Integration workflows (backup, migration, roundtrip)${NC}"
    echo -e "${CYAN}  ✓ --all-versions flag functionality and compatibility${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME IMPORT/EXPORT TESTS FAILED${NC}"
    echo -e "${YELLOW}Please review the failed test suites above and fix the issues.${NC}"
    exit 1
fi 