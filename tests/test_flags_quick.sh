#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT_DIR/build/ksr-cli"

echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}   KSR-CLI FLAGS QUICK TEST${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""

# Check if CLI binary exists
if [ ! -f "$CLI" ]; then
    echo -e "${RED}Error: CLI binary not found at $CLI${NC}"
    echo -e "${YELLOW}Please build the CLI first: make build${NC}"
    exit 1
fi

# Test 1: Help output includes new flags
echo -e "${BLUE}[TEST 1] Checking help output for new flags...${NC}"
HELP_OUTPUT=$($CLI --help)
if echo "$HELP_OUTPUT" | grep -q "registry-url.*Schema Registry instance URL" && \
   echo "$HELP_OUTPUT" | grep -q "user.*Username for authentication" && \
   echo "$HELP_OUTPUT" | grep -q "pass.*Password for authentication" && \
   echo "$HELP_OUTPUT" | grep -q "api-key.*API key for authentication"; then
    echo -e "${GREEN}✓ PASSED: All new flags present in help${NC}"
else
    echo -e "${RED}✗ FAILED: Missing flags in help output${NC}"
    exit 1
fi

# Test 2: Global flags available in subcommands
echo -e "${BLUE}[TEST 2] Checking global flags in subcommands...${NC}"
SUBCOMMAND_HELP=$($CLI get subjects --help)
if echo "$SUBCOMMAND_HELP" | grep -q "registry-url" && \
   echo "$SUBCOMMAND_HELP" | grep -q "user" && \
   echo "$SUBCOMMAND_HELP" | grep -q "pass" && \
   echo "$SUBCOMMAND_HELP" | grep -q "api-key"; then
    echo -e "${GREEN}✓ PASSED: Global flags available in subcommands${NC}"
else
    echo -e "${RED}✗ FAILED: Global flags not available in subcommands${NC}"
    exit 1
fi

# Test 3: Error handling for missing registry URL
echo -e "${BLUE}[TEST 3] Testing error handling for missing registry URL...${NC}"
# Clear any existing config and environment
TEMP_CONFIG=""
if [ -f ~/.ksr-cli.yaml ]; then
    TEMP_CONFIG=$(cat ~/.ksr-cli.yaml)
    rm ~/.ksr-cli.yaml
fi

# Run in a clean environment
ERROR_OUTPUT=$(env -u KSR_REGISTRY_URL -u KSR_USERNAME -u KSR_PASSWORD -u KSR_API_KEY $CLI get subjects 2>&1 || true)
if echo "$ERROR_OUTPUT" | grep -q "registry URL is required.*--registry-url"; then
    echo -e "${GREEN}✓ PASSED: Proper error when registry URL is missing${NC}"
else
    echo -e "${RED}✗ FAILED: Should show proper error when registry URL is missing${NC}"
    echo "Actual output: $ERROR_OUTPUT"
    exit 1
fi

# Restore config if it existed
if [ -n "$TEMP_CONFIG" ]; then
    echo "$TEMP_CONFIG" > ~/.ksr-cli.yaml
fi

# Test 4: Flag syntax validation (dry run without actual registry)
echo -e "${BLUE}[TEST 4] Testing flag syntax validation...${NC}"
if $CLI get subjects --registry-url http://example.com:8081 --user testuser --pass testpass --help >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED: Flag syntax validation works${NC}"
else
    echo -e "${RED}✗ FAILED: Flag syntax validation failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 All quick flag tests passed! 🎉${NC}"
echo -e "${CYAN}The command-line flags functionality is working correctly.${NC}"
echo ""
echo -e "${YELLOW}To run comprehensive integration tests:${NC}"
echo -e "${YELLOW}  cd tests && ./run-integration-tests.sh${NC}"
echo "" 