#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLI="../../build/ksr-cli"

echo -e "${BLUE}=== Testing Command Line Flags ===${NC}"

# Test 1: Basic registry-url flag functionality
echo -e "${YELLOW}[TEST] Registry URL flag functionality...${NC}"
if $CLI get subjects --registry-url http://localhost:38081 | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Registry URL flag works${NC}"
else
    echo -e "${RED}✗ FAILED: Registry URL flag failed${NC}"
    exit 1
fi

# Test 2: Test with invalid registry URL
echo -e "${YELLOW}[TEST] Invalid registry URL error handling...${NC}"
if $CLI get subjects --registry-url http://invalid-registry:9999 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with invalid registry URL${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled invalid registry URL${NC}"
fi

# Test 3: Test flag precedence over environment variable
echo -e "${YELLOW}[TEST] Flag precedence over environment variable...${NC}"
export KSR_REGISTRY_URL="http://invalid-registry:9999"
if $CLI get subjects --registry-url http://localhost:38081 | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Flag overrides environment variable${NC}"
else
    echo -e "${RED}✗ FAILED: Flag precedence failed${NC}"
    exit 1
fi
unset KSR_REGISTRY_URL

# Test 4: Test flag precedence over config file
echo -e "${YELLOW}[TEST] Flag precedence over config file...${NC}"
# Save original config
ORIGINAL_CONFIG=""
if [ -f ~/.ksr-cli.yaml ]; then
    ORIGINAL_CONFIG=$(cat ~/.ksr-cli.yaml)
fi

# Create temp config with wrong URL
echo "registry-url: http://invalid-registry:9999" > ~/.ksr-cli.yaml
if $CLI get subjects --registry-url http://localhost:38081 | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Flag overrides config file${NC}"
else
    echo -e "${RED}✗ FAILED: Flag precedence over config failed${NC}"
    exit 1
fi

# Restore original config
if [ -n "$ORIGINAL_CONFIG" ]; then
    echo "$ORIGINAL_CONFIG" > ~/.ksr-cli.yaml
else
    rm -f ~/.ksr-cli.yaml
fi

# Test 5: Test multiple flags together
echo -e "${YELLOW}[TEST] Multiple flags together...${NC}"
if $CLI get subjects --registry-url http://localhost:38081 --verbose | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Multiple flags work together${NC}"
else
    echo -e "${RED}✗ FAILED: Multiple flags failed${NC}"
    exit 1
fi

# Test 6: Test authentication flags with valid registry (no actual auth required)
echo -e "${YELLOW}[TEST] Authentication flags syntax...${NC}"
if $CLI get subjects --registry-url http://localhost:38081 --user testuser --pass testpass | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Authentication flags syntax works${NC}"
else
    echo -e "${RED}✗ FAILED: Authentication flags syntax failed${NC}"
    exit 1
fi

# Test 7: Test API key flag syntax
echo -e "${YELLOW}[TEST] API key flag syntax...${NC}"
if $CLI get subjects --registry-url http://localhost:38081 --api-key dummy-key | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: API key flag syntax works${NC}"
else
    echo -e "${RED}✗ FAILED: API key flag syntax failed${NC}"
    exit 1
fi

# Test 8: Test that user and pass flags work together
echo -e "${YELLOW}[TEST] User and password flags together...${NC}"
if $CLI get subjects --registry-url http://localhost:38081 --user admin --pass secret | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: User and password flags work together${NC}"
else
    echo -e "${RED}✗ FAILED: User and password flags failed${NC}"
    exit 1
fi

# Test 9: Test flags with schema operations
echo -e "${YELLOW}[TEST] Flags with schema operations...${NC}"
if $CLI get schemas user-value --registry-url http://localhost:38081 --user testuser --pass testpass | grep -q "User"; then
    echo -e "${GREEN}✓ PASSED: Flags work with schema operations${NC}"
else
    echo -e "${RED}✗ FAILED: Flags with schema operations failed${NC}"
    exit 1
fi

# Test 10: Test flags with create operations
echo -e "${YELLOW}[TEST] Flags with create operations...${NC}"
TEMP_SCHEMA=$(mktemp)
cat > "$TEMP_SCHEMA" << 'EOF'
{
  "type": "record",
  "name": "TestFlagSchema",
  "namespace": "com.example",
  "fields": [
    {"name": "id", "type": "string"},
    {"name": "name", "type": "string"}
  ]
}
EOF

if $CLI create schema test-flag-subject --file "$TEMP_SCHEMA" --registry-url http://localhost:38081 --user testuser --pass testpass; then
    echo -e "${GREEN}✓ PASSED: Flags work with create operations${NC}"
    # Clean up
    $CLI set delete test-flag-subject --registry-url http://localhost:38081 2>/dev/null || true
else
    echo -e "${RED}✗ FAILED: Flags with create operations failed${NC}"
    exit 1
fi
rm -f "$TEMP_SCHEMA"

# Test 11: Test flags with check operations
echo -e "${YELLOW}[TEST] Flags with check operations...${NC}"
if $CLI check compatibility user-value --file ../test-data/schemas/user-v2.avsc --registry-url http://localhost:38081 --user testuser --pass testpass; then
    echo -e "${GREEN}✓ PASSED: Flags work with check operations${NC}"
else
    echo -e "${RED}✗ FAILED: Flags with check operations failed${NC}"
    exit 1
fi

# Test 12: Test flags with config operations
echo -e "${YELLOW}[TEST] Flags with config operations...${NC}"
if $CLI get config --registry-url http://localhost:38081 --user testuser --pass testpass; then
    echo -e "${GREEN}✓ PASSED: Flags work with config operations${NC}"
else
    echo -e "${RED}✗ FAILED: Flags with config operations failed${NC}"
    exit 1
fi

# Test 13: Test flags with mode operations
echo -e "${YELLOW}[TEST] Flags with mode operations...${NC}"
if $CLI get mode --registry-url http://localhost:38081 --user testuser --pass testpass | grep -q "READWRITE\|READONLY\|IMPORT"; then
    echo -e "${GREEN}✓ PASSED: Flags work with mode operations${NC}"
else
    echo -e "${RED}✗ FAILED: Flags with mode operations failed${NC}"
    exit 1
fi

# Test 14: Test flags with export operations
echo -e "${YELLOW}[TEST] Flags with export operations...${NC}"
TEMP_EXPORT=$(mktemp)
if $CLI export subject user-value --file "$TEMP_EXPORT" --registry-url http://localhost:38081 --user testuser --pass testpass; then
    if [ -s "$TEMP_EXPORT" ] && grep -q "User" "$TEMP_EXPORT"; then
        echo -e "${GREEN}✓ PASSED: Flags work with export operations${NC}"
    else
        echo -e "${RED}✗ FAILED: Export file is empty or invalid${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ FAILED: Flags with export operations failed${NC}"
    exit 1
fi
rm -f "$TEMP_EXPORT"

# Test 15: Test error message when registry URL is missing
echo -e "${YELLOW}[TEST] Error handling when registry URL is missing...${NC}"
# Clear any existing config and environment
TEMP_CONFIG=""
if [ -f ~/.ksr-cli.yaml ]; then
    TEMP_CONFIG=$(cat ~/.ksr-cli.yaml)
    rm ~/.ksr-cli.yaml
fi

ERROR_OUTPUT=$(env -u KSR_REGISTRY_URL -u KSR_USERNAME -u KSR_PASSWORD -u KSR_API_KEY $CLI get subjects 2>&1 || true)
if echo "$ERROR_OUTPUT" | grep -q "registry URL is required.*--registry-url"; then
    echo -e "${GREEN}✓ PASSED: Proper error when registry URL is missing${NC}"
else
    echo -e "${RED}✗ FAILED: Should show proper error when registry URL is missing${NC}"
    exit 1
fi

# Restore config if it existed
if [ -n "$TEMP_CONFIG" ]; then
    echo "$TEMP_CONFIG" > ~/.ksr-cli.yaml
fi

# Test 16: Test flag help text
echo -e "${YELLOW}[TEST] Flag help text...${NC}"
HELP_OUTPUT=$($CLI --help)
if echo "$HELP_OUTPUT" | grep -q "registry-url.*Schema Registry instance URL" && \
   echo "$HELP_OUTPUT" | grep -q "user.*Username for authentication" && \
   echo "$HELP_OUTPUT" | grep -q "pass.*Password for authentication" && \
   echo "$HELP_OUTPUT" | grep -q "api-key.*API key for authentication"; then
    echo -e "${GREEN}✓ PASSED: Flag help text is correct${NC}"
else
    echo -e "${RED}✗ FAILED: Flag help text is incomplete${NC}"
    echo "Help output:"
    echo "$HELP_OUTPUT"
    exit 1
fi

# Test 17: Test global flags are available in subcommands
echo -e "${YELLOW}[TEST] Global flags available in subcommands...${NC}"
SUBCOMMAND_HELP=$($CLI get subjects --help)
if echo "$SUBCOMMAND_HELP" | grep -q "registry-url.*Schema Registry instance URL" && \
   echo "$SUBCOMMAND_HELP" | grep -q "user.*Username for authentication" && \
   echo "$SUBCOMMAND_HELP" | grep -q "pass.*Password for authentication" && \
   echo "$SUBCOMMAND_HELP" | grep -q "api-key.*API key for authentication"; then
    echo -e "${GREEN}✓ PASSED: Global flags available in subcommands${NC}"
else
    echo -e "${RED}✗ FAILED: Global flags not available in subcommands${NC}"
    exit 1
fi

# Test 18: Test mixed authentication methods (should prefer API key)
echo -e "${YELLOW}[TEST] Mixed authentication methods...${NC}"
if $CLI get subjects --registry-url http://localhost:38081 --user testuser --pass testpass --api-key dummy-key | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Mixed authentication methods work${NC}"
else
    echo -e "${RED}✗ FAILED: Mixed authentication methods failed${NC}"
    exit 1
fi

echo -e "${GREEN}All command line flag tests passed!${NC}" 