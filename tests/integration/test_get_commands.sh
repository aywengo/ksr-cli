#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLI="../../build/ksr-cli"

echo -e "${BLUE}=== Testing GET Commands ===${NC}"

# Test 1: Get all subjects
echo -e "${YELLOW}[TEST] Get all subjects...${NC}"
SUBJECTS_OUTPUT=$($CLI get subjects)
if echo "$SUBJECTS_OUTPUT" | grep -q "user-value\|order-value\|product-value"; then
    echo -e "${GREEN}✓ PASSED: Got subjects list${NC}"
else
    echo -e "${RED}✗ FAILED: Subjects list incomplete${NC}"
    echo "Output: $SUBJECTS_OUTPUT"
    exit 1
fi

# Test 2: Get specific schema (latest version)
echo -e "${YELLOW}[TEST] Get specific schema (latest)...${NC}"
if $CLI get schemas user-value | grep -q "User"; then
    echo -e "${GREEN}✓ PASSED: Got latest schema${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to get latest schema${NC}"
    exit 1
fi

# Test 3: Get specific version
echo -e "${YELLOW}[TEST] Get specific version...${NC}"
if $CLI get schemas user-value --version 1 | grep -q "User"; then
    echo -e "${GREEN}✓ PASSED: Got specific version${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to get specific version${NC}"
    exit 1
fi

# Test 4: Get all versions
echo -e "${YELLOW}[TEST] Get all versions...${NC}"
if $CLI get schemas user-value --all | grep -q "User"; then
    echo -e "${GREEN}✓ PASSED: Got all versions${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to get all versions${NC}"
    exit 1
fi

# Test 5: Get subject versions
echo -e "${YELLOW}[TEST] Get subject versions...${NC}"
VERSIONS_OUTPUT=$($CLI get versions user-value)
if echo "$VERSIONS_OUTPUT" | grep -E "[0-9]+"; then
    echo -e "${GREEN}✓ PASSED: Got version numbers${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to get version numbers${NC}"
    echo "Output: $VERSIONS_OUTPUT"
    exit 1
fi

# Test 6: Get global config
echo -e "${YELLOW}[TEST] Get global config...${NC}"
GLOBAL_CONFIG_OUTPUT=$($CLI get config 2>&1 || true)
if [ -n "$GLOBAL_CONFIG_OUTPUT" ] && ! echo "$GLOBAL_CONFIG_OUTPUT" | grep -q "Error\|error\|FAILED"; then
    echo -e "${GREEN}✓ PASSED: Got global config${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to get global config${NC}"
    echo "Output: $GLOBAL_CONFIG_OUTPUT"
    exit 1
fi

# Test 7: Get subject config
echo -e "${YELLOW}[TEST] Get subject config...${NC}"
SUBJECT_CONFIG_OUTPUT=$($CLI get config user-value 2>&1 || true)
if echo "$SUBJECT_CONFIG_OUTPUT" | grep -q "40408\|does not have subject-level"; then
    echo -e "${GREEN}✓ PASSED: Subject config correctly returns no subject-level config${NC}"
elif [ -n "$SUBJECT_CONFIG_OUTPUT" ] && ! echo "$SUBJECT_CONFIG_OUTPUT" | grep -q "Error\|error\|FAILED"; then
    echo -e "${GREEN}✓ PASSED: Got subject config${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to get subject config${NC}"
    echo "Output: $SUBJECT_CONFIG_OUTPUT"
    exit 1
fi

# Test 8: JSON output format
echo -e "${YELLOW}[TEST] JSON output format...${NC}"
JSON_OUTPUT=$($CLI get subjects --output json)
if echo "$JSON_OUTPUT" | python3 -m json.tool > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED: Valid JSON output${NC}"
else
    echo -e "${RED}✗ FAILED: Invalid JSON output${NC}"
    echo "Output: $JSON_OUTPUT"
    exit 1
fi

# Test 9: YAML output format
echo -e "${YELLOW}[TEST] YAML output format...${NC}"
YAML_OUTPUT=$($CLI get subjects --output yaml)
if echo "$YAML_OUTPUT" | grep -E "^-\s"; then
    echo -e "${GREEN}✓ PASSED: YAML format detected${NC}"
else
    echo -e "${RED}✗ FAILED: Invalid YAML output${NC}"
    echo "Output: $YAML_OUTPUT"
    exit 1
fi

# Test 10: Context-specific operations
echo -e "${YELLOW}[TEST] Context-specific operations...${NC}"
# This assumes we created a schema in test-context earlier
if $CLI get subjects --context test-context | grep -q "product-test-value"; then
    echo -e "${GREEN}✓ PASSED: Context-specific operation${NC}"
else
    echo -e "${RED}✗ FAILED: Context-specific operation failed${NC}"
    exit 1
fi

# Test 11: Error handling - non-existent subject
echo -e "${YELLOW}[TEST] Error handling - non-existent subject...${NC}"
if $CLI get schemas non-existent-subject 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with non-existent subject${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled non-existent subject${NC}"
fi

# Test 12: Error handling - non-existent version
echo -e "${YELLOW}[TEST] Error handling - non-existent version...${NC}"
if $CLI get schemas user-value --version 999 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with non-existent version${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled non-existent version${NC}"
fi

echo -e "${GREEN}All GET command tests passed!${NC}" 