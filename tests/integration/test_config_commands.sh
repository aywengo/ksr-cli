#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLI="../../build/ksr-cli"

echo -e "${BLUE}=== Testing CONFIG Commands ===${NC}"

# Cleanup function - will be set dynamically
cleanup() {
    rm -f "$HOME"/.ksr-cli-test-*.yaml 2>/dev/null || true
}
trap cleanup EXIT

# Test 1: Config init
echo -e "${YELLOW}[TEST] Config init...${NC}"
# Use a unique config file for testing to avoid conflicts
CONFIG_FILE="$HOME/.ksr-cli-test-$(date +%s).yaml"
# Remove existing config if present
rm -f "$CONFIG_FILE" 2>/dev/null || true
INIT_OUTPUT=$($CLI config init 2>&1 || true)
if echo "$INIT_OUTPUT" | grep -q "created\|exists" || [ -f "$HOME/.ksr-cli.yaml" ]; then
    echo -e "${GREEN}✓ PASSED: Config init successful${NC}"
else
    echo -e "${RED}✗ FAILED: Config init failed${NC}"
    echo "Output: $INIT_OUTPUT"
    exit 1
fi

# Test 2: Set registry-url
echo -e "${YELLOW}[TEST] Set registry-url...${NC}"
if $CLI config set registry-url http://localhost:38081; then
    echo -e "${GREEN}✓ PASSED: Registry URL set${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to set registry URL${NC}"
    exit 1
fi

# Test 3: Get registry-url
echo -e "${YELLOW}[TEST] Get registry-url...${NC}"
REGISTRY_URL=$($CLI config get registry-url)
if echo "$REGISTRY_URL" | grep -q "http://localhost:38081"; then
    echo -e "${GREEN}✓ PASSED: Registry URL retrieved${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to get registry URL${NC}"
    echo "Output: $REGISTRY_URL"
    exit 1
fi

# Test 4: Set output format
echo -e "${YELLOW}[TEST] Set output format...${NC}"
if $CLI config set output json; then
    echo -e "${GREEN}✓ PASSED: Output format set${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to set output format${NC}"
    exit 1
fi

# Test 5: Get output format
echo -e "${YELLOW}[TEST] Get output format...${NC}"
OUTPUT_FORMAT=$($CLI config get output)
if echo "$OUTPUT_FORMAT" | grep -q "json"; then
    echo -e "${GREEN}✓ PASSED: Output format retrieved${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to get output format${NC}"
    echo "Output: $OUTPUT_FORMAT"
    exit 1
fi

# Test 6: Set context
echo -e "${YELLOW}[TEST] Set context...${NC}"
if $CLI config set context production; then
    echo -e "${GREEN}✓ PASSED: Context set${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to set context${NC}"
    exit 1
fi

# Test 7: Get context
echo -e "${YELLOW}[TEST] Get context...${NC}"
CONTEXT_VALUE=$($CLI config get context)
if echo "$CONTEXT_VALUE" | grep -q "production"; then
    echo -e "${GREEN}✓ PASSED: Context retrieved${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to get context${NC}"
    echo "Output: $CONTEXT_VALUE"
    exit 1
fi

# Test 8: Set timeout
echo -e "${YELLOW}[TEST] Set timeout...${NC}"
if $CLI config set timeout 60s; then
    echo -e "${GREEN}✓ PASSED: Timeout set${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to set timeout${NC}"
    exit 1
fi

# Test 9: Set insecure flag
echo -e "${YELLOW}[TEST] Set insecure flag...${NC}"
if $CLI config set insecure true; then
    echo -e "${GREEN}✓ PASSED: Insecure flag set${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to set insecure flag${NC}"
    exit 1
fi

# Test 10: List all configuration
echo -e "${YELLOW}[TEST] List all configuration...${NC}"
CONFIG_LIST=$($CLI config list)
if echo "$CONFIG_LIST" | grep -q "REGISTRY-URL\|OUTPUT\|CONTEXT" || echo "$CONFIG_LIST" | grep -q "registry-url\|output\|context"; then
    echo -e "${GREEN}✓ PASSED: Configuration list retrieved${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to list configuration${NC}"
    echo "Output: $CONFIG_LIST"
    exit 1
fi

# Test 11: Config validation
echo -e "${YELLOW}[TEST] Config validation...${NC}"
if $CLI config validate | grep -q "Registry URL"; then
    echo -e "${GREEN}✓ PASSED: Config validation works${NC}"
else
    echo -e "${RED}✗ FAILED: Config validation failed${NC}"
    exit 1
fi

# Test 12: Error handling - invalid output format
echo -e "${YELLOW}[TEST] Error handling - invalid output format...${NC}"
if $CLI config set output invalid-format 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with invalid output format${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled invalid output format${NC}"
fi

# Test 13: Error handling - invalid boolean value
echo -e "${YELLOW}[TEST] Error handling - invalid boolean value...${NC}"
if $CLI config set insecure invalid-boolean 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with invalid boolean value${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled invalid boolean value${NC}"
fi

# Test 14: Error handling - invalid configuration key
echo -e "${YELLOW}[TEST] Error handling - invalid configuration key...${NC}"
if $CLI config set invalid-key some-value 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with invalid configuration key${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled invalid configuration key${NC}"
fi

# Test 15: Get non-existent key
echo -e "${YELLOW}[TEST] Get non-existent key...${NC}"
NON_EXISTENT_OUTPUT=$($CLI config get non-existent-key)
if echo "$NON_EXISTENT_OUTPUT" | grep -q "is not set"; then
    echo -e "${GREEN}✓ PASSED: Correctly handled non-existent key${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to handle non-existent key${NC}"
    echo "Output: $NON_EXISTENT_OUTPUT"
    exit 1
fi

# Test 16: Set username and password (for auth testing)
echo -e "${YELLOW}[TEST] Set authentication credentials...${NC}"
if $CLI config set username testuser && $CLI config set password testpass; then
    echo -e "${GREEN}✓ PASSED: Authentication credentials set${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to set authentication credentials${NC}"
    exit 1
fi

# Test 17: Set API key
echo -e "${YELLOW}[TEST] Set API key...${NC}"
if $CLI config set api-key test-api-key-12345; then
    echo -e "${GREEN}✓ PASSED: API key set${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to set API key${NC}"
    exit 1
fi

# Test 18: Reset context to default
echo -e "${YELLOW}[TEST] Reset context to default...${NC}"
if $CLI config set context .; then
    echo -e "${GREEN}✓ PASSED: Context reset to default${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to reset context${NC}"
    exit 1
fi

# Test 19: Verify context persistence
echo -e "${YELLOW}[TEST] Verify context persistence...${NC}"
CURRENT_CONTEXT=$($CLI config get context)
if echo "$CURRENT_CONTEXT" | grep -q "\."; then
    echo -e "${GREEN}✓ PASSED: Context persisted correctly${NC}"
else
    echo -e "${RED}✗ FAILED: Context not persisted${NC}"
    echo "Output: $CURRENT_CONTEXT"
    exit 1
fi

echo -e "${GREEN}All CONFIG command tests passed!${NC}" 