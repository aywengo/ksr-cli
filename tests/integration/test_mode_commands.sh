#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLI="../../build/ksr-cli"

echo -e "${BLUE}=== Testing MODE Commands ===${NC}"

# Test 1: Get global mode (should be READWRITE by default)
echo -e "${YELLOW}[TEST] Get global mode...${NC}"
GLOBAL_MODE_OUTPUT=$($CLI get mode)
if echo "$GLOBAL_MODE_OUTPUT" | grep -q "READWRITE\|READONLY\|IMPORT"; then
    echo -e "${GREEN}✓ PASSED: Got global mode${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to get global mode${NC}"
    echo "Output: $GLOBAL_MODE_OUTPUT"
    exit 1
fi

# Test 2: Set global mode to READONLY
echo -e "${YELLOW}[TEST] Set global mode to READONLY...${NC}"
READONLY_OUTPUT=$($CLI set mode READONLY)
if echo "$READONLY_OUTPUT" | grep -q "READONLY"; then
    echo -e "${GREEN}✓ PASSED: Set global mode to READONLY${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to set global mode to READONLY${NC}"
    echo "Output: $READONLY_OUTPUT"
    exit 1
fi

# Test 3: Verify global mode is now READONLY
echo -e "${YELLOW}[TEST] Verify global mode is READONLY...${NC}"
VERIFY_READONLY_OUTPUT=$($CLI get mode)
if echo "$VERIFY_READONLY_OUTPUT" | grep -q "READONLY"; then
    echo -e "${GREEN}✓ PASSED: Global mode is READONLY${NC}"
else
    echo -e "${RED}✗ FAILED: Global mode verification failed${NC}"
    echo "Output: $VERIFY_READONLY_OUTPUT"
    exit 1
fi

# Test 4: Set global mode back to READWRITE
echo -e "${YELLOW}[TEST] Set global mode back to READWRITE...${NC}"
READWRITE_OUTPUT=$($CLI set mode READWRITE)
if echo "$READWRITE_OUTPUT" | grep -q "READWRITE"; then
    echo -e "${GREEN}✓ PASSED: Set global mode to READWRITE${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to set global mode to READWRITE${NC}"
    echo "Output: $READWRITE_OUTPUT"
    exit 1
fi

# Test 5: Test IMPORT mode (may fail if subjects exist)
echo -e "${YELLOW}[TEST] Set global mode to IMPORT...${NC}"
IMPORT_OUTPUT=$($CLI set mode IMPORT 2>&1 || true)
if echo "$IMPORT_OUTPUT" | grep -q "IMPORT"; then
    echo -e "${GREEN}✓ PASSED: Set global mode to IMPORT${NC}"
elif echo "$IMPORT_OUTPUT" | grep -q "42205\|Cannot import since found existing subjects"; then
    echo -e "${YELLOW}⚠ SKIPPED: Cannot set IMPORT mode with existing subjects (expected behavior)${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to set global mode to IMPORT${NC}"
    echo "Output: $IMPORT_OUTPUT"
    exit 1
fi

# Test 6: Reset to READWRITE for further testing
echo -e "${YELLOW}[TEST] Reset global mode to READWRITE...${NC}"
$CLI set mode READWRITE > /dev/null
echo -e "${GREEN}✓ PASSED: Reset global mode to READWRITE${NC}"

# Test 7: Set subject-specific mode
echo -e "${YELLOW}[TEST] Set subject mode to READONLY...${NC}"
# First, ensure we have a subject to work with
SUBJECT_MODE_OUTPUT=$($CLI set mode user-value READONLY 2>&1 || true)
if echo "$SUBJECT_MODE_OUTPUT" | grep -q "READONLY"; then
    echo -e "${GREEN}✓ PASSED: Set subject mode to READONLY${NC}"
elif echo "$SUBJECT_MODE_OUTPUT" | grep -q "40401\|Subject.*not found\|does not exist"; then
    echo -e "${YELLOW}⚠ SKIPPED: Subject user-value doesn't exist (expected in some test scenarios)${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to set subject mode${NC}"
    echo "Output: $SUBJECT_MODE_OUTPUT"
    exit 1
fi

# Test 8: Get subject-specific mode (if subject exists)
echo -e "${YELLOW}[TEST] Get subject mode...${NC}"
SUBJECT_GET_OUTPUT=$($CLI get mode user-value 2>&1 || true)
if echo "$SUBJECT_GET_OUTPUT" | grep -q "READONLY\|READWRITE\|IMPORT"; then
    echo -e "${GREEN}✓ PASSED: Got subject mode${NC}"
elif echo "$SUBJECT_GET_OUTPUT" | grep -q "40401\|Subject.*not found\|does not exist"; then
    echo -e "${YELLOW}⚠ SKIPPED: Subject user-value doesn't exist (expected in some test scenarios)${NC}"
else
    echo -e "${RED}✗ FAILED: Failed to get subject mode${NC}"
    echo "Output: $SUBJECT_GET_OUTPUT"
    exit 1
fi

# Test 9: JSON output format for global mode
echo -e "${YELLOW}[TEST] JSON output format for global mode...${NC}"
JSON_MODE_OUTPUT=$($CLI get mode --output json)
if echo "$JSON_MODE_OUTPUT" | python3 -m json.tool > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED: Valid JSON output for mode${NC}"
else
    echo -e "${RED}✗ FAILED: Invalid JSON output for mode${NC}"
    echo "Output: $JSON_MODE_OUTPUT"
    exit 1
fi

# Test 10: YAML output format for global mode
echo -e "${YELLOW}[TEST] YAML output format for global mode...${NC}"
YAML_MODE_OUTPUT=$($CLI get mode --output yaml)
if echo "$YAML_MODE_OUTPUT" | grep -E "mode:|READWRITE|READONLY|IMPORT"; then
    echo -e "${GREEN}✓ PASSED: YAML format detected for mode${NC}"
else
    echo -e "${RED}✗ FAILED: Invalid YAML output for mode${NC}"
    echo "Output: $YAML_MODE_OUTPUT"
    exit 1
fi

# Test 11: Context-specific mode operations
echo -e "${YELLOW}[TEST] Context-specific mode operations...${NC}"
CONTEXT_MODE_OUTPUT=$($CLI get mode --context test-context 2>&1 || true)
if echo "$CONTEXT_MODE_OUTPUT" | grep -q "READWRITE\|READONLY\|IMPORT"; then
    echo -e "${GREEN}✓ PASSED: Context-specific mode operation${NC}"
elif echo "$CONTEXT_MODE_OUTPUT" | grep -q "context.*not found\|does not exist"; then
    echo -e "${YELLOW}⚠ SKIPPED: Context test-context doesn't exist (expected in some test scenarios)${NC}"
else
    echo -e "${RED}✗ FAILED: Context-specific mode operation failed${NC}"
    echo "Output: $CONTEXT_MODE_OUTPUT"
    exit 1
fi

# Test 12: Error handling - invalid mode
echo -e "${YELLOW}[TEST] Error handling - invalid mode...${NC}"
if $CLI set mode INVALID_MODE 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with invalid mode${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly rejected invalid mode${NC}"
fi

# Test 13: Error handling - missing arguments
echo -e "${YELLOW}[TEST] Error handling - missing arguments...${NC}"
if $CLI set mode 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with missing arguments${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled missing arguments${NC}"
fi

# Test 14: Case sensitivity - lowercase mode should be rejected
echo -e "${YELLOW}[TEST] Error handling - lowercase mode...${NC}"
if $CLI set mode readonly 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with lowercase mode${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly rejected lowercase mode${NC}"
fi

# Test 14b: Validate IMPORT mode is recognized as valid (even if can't be set)
echo -e "${YELLOW}[TEST] IMPORT mode validation...${NC}"
IMPORT_VALIDATION_OUTPUT=$($CLI set mode IMPORT 2>&1 || true)
if echo "$IMPORT_VALIDATION_OUTPUT" | grep -q "invalid mode.*IMPORT"; then
    echo -e "${RED}✗ FAILED: IMPORT should be recognized as valid mode${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: IMPORT mode is recognized as valid${NC}"
fi

# Test 15: Test mode persistence across get operations
echo -e "${YELLOW}[TEST] Mode persistence across operations...${NC}"
$CLI set mode READONLY > /dev/null
FIRST_GET=$($CLI get mode)
SECOND_GET=$($CLI get mode)
if echo "$FIRST_GET" | grep -q "READONLY" && echo "$SECOND_GET" | grep -q "READONLY"; then
    echo -e "${GREEN}✓ PASSED: Mode persists across operations${NC}"
else
    echo -e "${RED}✗ FAILED: Mode doesn't persist across operations${NC}"
    echo "First get: $FIRST_GET"
    echo "Second get: $SECOND_GET"
    exit 1
fi

# Cleanup: Reset to READWRITE mode
echo -e "${YELLOW}[CLEANUP] Resetting global mode to READWRITE...${NC}"
$CLI set mode READWRITE > /dev/null
echo -e "${GREEN}✓ PASSED: Reset to READWRITE${NC}"

echo -e "${GREEN}All MODE command tests passed!${NC}" 