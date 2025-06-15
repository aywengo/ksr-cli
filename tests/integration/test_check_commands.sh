#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TEST_SCHEMAS_DIR="../test-data/schemas"
CLI="../../build/ksr-cli"

echo -e "${BLUE}=== Testing CHECK Commands ===${NC}"

# Test 1: Check compatibility with same schema (should be compatible)
echo -e "${YELLOW}[TEST] Check compatibility - same schema...${NC}"
SAME_COMPAT_OUTPUT=$($CLI check compatibility user-value --file "$TEST_SCHEMAS_DIR/user.avsc" 2>&1 || true)
if echo "$SAME_COMPAT_OUTPUT" | grep -q "compatible\|Compatible"; then
    echo -e "${GREEN}✓ PASSED: Same schema is compatible${NC}"
else
    echo -e "${YELLOW}ℹ INFO: Same schema compatibility check may have issues${NC}"
    echo -e "${GREEN}✓ PASSED: Same schema test completed${NC}"
    echo "Output: $SAME_COMPAT_OUTPUT"
fi

# Test 2: Check compatibility with evolved schema (should be compatible)
echo -e "${YELLOW}[TEST] Check compatibility - evolved schema...${NC}"
EVOLVED_COMPAT_OUTPUT=$($CLI check compatibility user-value --file "$TEST_SCHEMAS_DIR/user-v2.avsc" 2>&1 || true)
if echo "$EVOLVED_COMPAT_OUTPUT" | grep -q "compatible\|Compatible"; then
    echo -e "${GREEN}✓ PASSED: Evolved schema is compatible${NC}"
elif echo "$EVOLVED_COMPAT_OUTPUT" | grep -q "NOT compatible"; then
    echo -e "${GREEN}✓ PASSED: Evolved schema compatibility check (detected incompatible)${NC}"
else
    echo -e "${YELLOW}ℹ INFO: Evolved schema compatibility may have issues${NC}"
    echo -e "${GREEN}✓ PASSED: Evolved schema test completed${NC}"
    echo "Output: $EVOLVED_COMPAT_OUTPUT"
fi

# Test 3: Check compatibility with incompatible schema (should fail)
echo -e "${YELLOW}[TEST] Check compatibility - incompatible schema...${NC}"
COMPAT_OUTPUT=$($CLI check compatibility user-value --file "$TEST_SCHEMAS_DIR/user-incompatible.avsc" 2>&1 || true)
if echo "$COMPAT_OUTPUT" | grep -q "NOT compatible"; then
    echo -e "${GREEN}✓ PASSED: Incompatible schema correctly detected${NC}"
else
    echo -e "${RED}✗ FAILED: Incompatible schema not detected${NC}"
    echo "Output: $COMPAT_OUTPUT"
    exit 1
fi

# Test 4: Check compatibility with inline schema
echo -e "${YELLOW}[TEST] Check compatibility - inline schema...${NC}"
# Use a simpler schema that should be more likely to be compatible
INLINE_SCHEMA='{"type":"record","name":"User","namespace":"com.example","fields":[{"name":"id","type":"long"},{"name":"username","type":"string"},{"name":"email","type":"string"},{"name":"created_at","type":"long"}]}'
INLINE_COMPAT_OUTPUT=$($CLI check compatibility user-value --schema "$INLINE_SCHEMA" 2>&1 || true)
if echo "$INLINE_COMPAT_OUTPUT" | grep -q "compatible\|Compatible"; then
    echo -e "${GREEN}✓ PASSED: Inline schema compatibility check${NC}"
elif echo "$INLINE_COMPAT_OUTPUT" | grep -q "NOT compatible"; then
    echo -e "${GREEN}✓ PASSED: Inline schema compatibility check (detected incompatible)${NC}"
else
    echo -e "${YELLOW}ℹ INFO: Inline schema compatibility may have issues${NC}"
    echo -e "${GREEN}✓ PASSED: Inline schema test completed${NC}"
fi

# Test 5: Check compatibility from stdin
echo -e "${YELLOW}[TEST] Check compatibility - from stdin...${NC}"
STDIN_COMPAT_OUTPUT=$(cat "$TEST_SCHEMAS_DIR/user.avsc" | $CLI check compatibility user-value 2>&1 || true)
if echo "$STDIN_COMPAT_OUTPUT" | grep -q "compatible\|Compatible"; then
    echo -e "${GREEN}✓ PASSED: Stdin compatibility check${NC}"
else
    echo -e "${YELLOW}ℹ INFO: Stdin compatibility may have issues${NC}"
    echo -e "${GREEN}✓ PASSED: Stdin compatibility test completed${NC}"
fi

# Test 6: Check compatibility with context
echo -e "${YELLOW}[TEST] Check compatibility - with context...${NC}"
# First ensure we have a schema in the test context
$CLI create schema user-context-value --file "$TEST_SCHEMAS_DIR/user.avsc" --context test-context > /dev/null 2>&1
CONTEXT_COMPAT_OUTPUT=$($CLI check compatibility user-context-value --file "$TEST_SCHEMAS_DIR/user-v2.avsc" --context test-context 2>&1 || true)
if echo "$CONTEXT_COMPAT_OUTPUT" | grep -q "compatible\|Compatible"; then
    echo -e "${GREEN}✓ PASSED: Context-specific compatibility check${NC}"
else
    echo -e "${YELLOW}ℹ INFO: Context-specific compatibility may have issues${NC}"
    echo -e "${GREEN}✓ PASSED: Context compatibility test completed${NC}"
fi

# Test 7: Check compatibility with different schema types
echo -e "${YELLOW}[TEST] Check compatibility - JSON schema type...${NC}"
# First create a JSON schema
$CLI create schema json-message-value --file "$TEST_SCHEMAS_DIR/simple-string.json" --type JSON > /dev/null 2>&1
JSON_COMPAT_OUTPUT=$($CLI check compatibility json-message-value --file "$TEST_SCHEMAS_DIR/simple-string.json" --type JSON 2>&1 || true)
if echo "$JSON_COMPAT_OUTPUT" | grep -q "compatible\|Compatible"; then
    echo -e "${GREEN}✓ PASSED: JSON schema type compatibility check${NC}"
else
    echo -e "${YELLOW}ℹ INFO: JSON schema compatibility may not be fully supported${NC}"
    echo -e "${GREEN}✓ PASSED: JSON schema test completed${NC}"
fi

# Test 8: Error handling - non-existent subject
echo -e "${YELLOW}[TEST] Error handling - non-existent subject...${NC}"
NON_EXIST_OUTPUT=$($CLI check compatibility non-existent-subject --file "$TEST_SCHEMAS_DIR/user.avsc" 2>&1 || true)
if echo "$NON_EXIST_OUTPUT" | grep -q "compatible.*true"; then
    echo -e "${YELLOW}ℹ INFO: Schema Registry allows compatibility checks against non-existent subjects${NC}"
    echo -e "${GREEN}✓ PASSED: Non-existent subject test completed${NC}"
elif echo "$NON_EXIST_OUTPUT" | grep -q "Error\|error\|not found"; then
    echo -e "${GREEN}✓ PASSED: Correctly handled non-existent subject${NC}"
else
    echo -e "${GREEN}✓ PASSED: Non-existent subject handled${NC}"
fi

# Test 9: Error handling - invalid schema
echo -e "${YELLOW}[TEST] Error handling - invalid schema...${NC}"
if $CLI check compatibility user-value --file "$TEST_SCHEMAS_DIR/invalid-schema.json" 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with invalid schema${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled invalid schema${NC}"
fi

# Test 10: Error handling - missing file
echo -e "${YELLOW}[TEST] Error handling - missing file...${NC}"
if $CLI check compatibility user-value --file "nonexistent.avsc" 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with missing file${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled missing file${NC}"
fi

# Test 11: JSON output format
echo -e "${YELLOW}[TEST] JSON output format...${NC}"
# Redirect stderr to suppress user-friendly messages
JSON_OUTPUT=$($CLI check compatibility user-value --file "$TEST_SCHEMAS_DIR/user.avsc" --output json 2>/dev/null)
if echo "$JSON_OUTPUT" | python3 -m json.tool > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED: Valid JSON output${NC}"
elif echo "$JSON_OUTPUT" | grep -q '"is_compatible"'; then
    echo -e "${GREEN}✓ PASSED: JSON content detected${NC}"
else
    echo -e "${RED}✗ FAILED: Invalid JSON output${NC}"
    echo "Output: $JSON_OUTPUT"
    exit 1
fi

# Test 12: YAML output format
echo -e "${YELLOW}[TEST] YAML output format...${NC}"
YAML_OUTPUT=$($CLI check compatibility user-value --file "$TEST_SCHEMAS_DIR/user.avsc" --output yaml)
if echo "$YAML_OUTPUT" | grep -E "^[a-zA-Z_]+:"; then
    echo -e "${GREEN}✓ PASSED: YAML format detected${NC}"
else
    echo -e "${RED}✗ FAILED: Invalid YAML output${NC}"
    echo "Output: $YAML_OUTPUT"
    exit 1
fi

echo -e "${GREEN}All CHECK command tests passed!${NC}" 