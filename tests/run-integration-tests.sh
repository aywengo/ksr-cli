#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$ROOT_DIR/tests"
SCHEMAS_DIR="$TESTS_DIR/test-data/schemas"
INTEGRATION_DIR="$TESTS_DIR/integration"
DOCKER_COMPOSE_FILE="$TESTS_DIR/docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=======================================${NC}"
echo -e "${CYAN}   KSR-CLI INTEGRATION TEST RUNNER${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

# 1. Build ksr-cli
cd "$ROOT_DIR"
echo -e "${BLUE}[INFO] Building ksr-cli...${NC}"
if make build > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

# 2. Start docker-compose environment
cd "$TESTS_DIR"
echo -e "${BLUE}[INFO] Starting test environment...${NC}"
docker-compose -f "$DOCKER_COMPOSE_FILE" up -d --remove-orphans

# 3. Wait for services to be healthy
echo -e "${BLUE}[INFO] Waiting for services to be healthy...${NC}"
ATTEMPTS=30
HEALTHY_SERVICES=0
while [ $ATTEMPTS -gt 0 ]; do
    HEALTHY_SERVICES=$(docker-compose -f "$DOCKER_COMPOSE_FILE" ps | grep -c "healthy" || true)
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
    echo -e "${YELLOW}Service status:${NC}"
    docker-compose -f "$DOCKER_COMPOSE_FILE" ps
    echo -e "${YELLOW}Logs:${NC}"
    docker-compose -f "$DOCKER_COMPOSE_FILE" logs --tail=50
    docker-compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans
    exit 1
fi

# Configure ksr-cli in the test directory
cd "$TESTS_DIR"
echo -e "${BLUE}[INFO] Configuring ksr-cli for test environment...${NC}"
"$ROOT_DIR/build/ksr-cli" config init > /dev/null 2>&1 || true
"$ROOT_DIR/build/ksr-cli" config set registry-url http://localhost:38081

# 4. Load initial test schemas
cd "$ROOT_DIR"
echo -e "${BLUE}[INFO] Registering initial test schemas...${NC}"
SCHEMA_COUNT=0
for schema in "$SCHEMAS_DIR"/*.avsc; do
    if [ -f "$schema" ]; then
        subject="$(basename "$schema" .avsc)-value"
        echo -e "${YELLOW}  Registering $schema as subject $subject...${NC}"
        cd "$TESTS_DIR"
        if "$ROOT_DIR/build/ksr-cli" create schema "$subject" --file "$schema" > /dev/null 2>&1; then
            SCHEMA_COUNT=$((SCHEMA_COUNT + 1))
        else
            echo -e "${YELLOW}    Warning: Failed to register $schema${NC}"
        fi
        cd "$ROOT_DIR"
    fi
done
echo -e "${GREEN}✓ Registered $SCHEMA_COUNT schemas${NC}"

# 5. Run comprehensive integration tests
cd "$INTEGRATION_DIR"
echo -e "${BLUE}[INFO] Running comprehensive integration tests...${NC}"
echo ""

if [ -f "test_comprehensive.sh" ]; then
    # Run the comprehensive test suite
    if bash test_comprehensive.sh; then
        echo -e "${GREEN}🎉 All integration tests passed! 🎉${NC}"
        TEST_RESULT=0
    else
        echo -e "${RED}❌ Some integration tests failed${NC}"
        TEST_RESULT=1
    fi
else
    # Fallback to running individual test scripts
    echo -e "${YELLOW}Comprehensive test suite not found, running individual tests...${NC}"
    TEST_RESULT=0
    for test_script in test_*.sh; do
        if [ -f "$test_script" ]; then
            echo -e "${BLUE}Running $test_script...${NC}"
            if bash "$test_script"; then
                echo -e "${GREEN}✓ $test_script passed${NC}"
            else
                echo -e "${RED}✗ $test_script failed${NC}"
                TEST_RESULT=1
            fi
            echo ""
        fi
    done
fi

# 6. Tear down environment
echo -e "${BLUE}[INFO] Tearing down test environment...${NC}"
cd "$TESTS_DIR"
docker-compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans > /dev/null 2>&1

echo ""
if [ $TEST_RESULT -eq 0 ]; then
    echo -e "${GREEN}🎉 Integration tests completed successfully! 🎉${NC}"
    echo -e "${GREEN}Your ksr-cli is working correctly across all tested scenarios.${NC}"
else
    echo -e "${RED}❌ Integration tests completed with failures${NC}"
    echo -e "${YELLOW}Please review the test output above and fix the failing tests.${NC}"
fi

exit $TEST_RESULT 