#!/bin/bash

# Set root and CLI path
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLI="${CLI:-$ROOT_DIR/build/ksr-cli}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Use a dedicated context for this test
TEST_CONTEXT="delete-test-context"

# Create and use the test context
$CLI config add-context "$TEST_CONTEXT" --registry-url http://localhost:38081 > /dev/null 2>&1
$CLI config use-context "$TEST_CONTEXT" > /dev/null 2>&1

# Test subject name
TEST_SUBJECT="test-delete-subject"

# Test 1: Delete specific version
echo -e "${YELLOW}[TEST] Delete specific version...${NC}"

# First register two versions
cat > schema1.json << EOF
{
  "type": "record",
  "name": "Test",
  "fields": [
    {"name": "field1", "type": "string"}
  ]
}
EOF

cat > schema2.json << EOF
{
  "type": "record",
  "name": "Test",
  "fields": [
    {"name": "field1", "type": "string"},
    {"name": "field2", "type": "int", "default": 0}
  ]
}
EOF

# Register first version
if ! $CLI create schema "$TEST_SUBJECT" --file schema1.json --context "$TEST_CONTEXT" > /dev/null; then
    echo -e "${RED}✗ FAILED: Failed to register first version${NC}"
    $CLI config delete-context "$TEST_CONTEXT" > /dev/null 2>&1
    exit 1
fi

# Register second version
if ! $CLI create schema "$TEST_SUBJECT" --file schema2.json --context "$TEST_CONTEXT" > /dev/null; then
    echo -e "${RED}✗ FAILED: Failed to register second version${NC}"
    $CLI config delete-context "$TEST_CONTEXT" > /dev/null 2>&1
    exit 1
fi

# Get versions before deletion
VERSIONS_BEFORE=$($CLI get versions "$TEST_SUBJECT" --context "$TEST_CONTEXT" 2>/dev/null || echo "[]")
VERSION_COUNT_BEFORE=$(echo "$VERSIONS_BEFORE" | grep -o '[0-9]\+' | wc -l)

# Delete version 1
if ! $CLI delete version "$TEST_SUBJECT" --version 1 --context "$TEST_CONTEXT" > /dev/null; then
    echo -e "${RED}✗ FAILED: Failed to delete version 1${NC}"
    $CLI config delete-context "$TEST_CONTEXT" > /dev/null 2>&1
    exit 1
fi

# Get versions after deletion
VERSIONS_AFTER=$($CLI get versions "$TEST_SUBJECT" --context "$TEST_CONTEXT" 2>/dev/null || echo "[]")
VERSION_COUNT_AFTER=$(echo "$VERSIONS_AFTER" | grep -o '[0-9]\+' | wc -l)

# Verify version was deleted
if [ "$VERSION_COUNT_AFTER" -eq $((VERSION_COUNT_BEFORE - 1)) ]; then
    echo -e "${GREEN}✓ PASSED: Successfully deleted version 1${NC}"
else
    echo -e "${RED}✗ FAILED: Version count mismatch after deletion (before: $VERSION_COUNT_BEFORE, after: $VERSION_COUNT_AFTER)${NC}"
    $CLI config delete-context "$TEST_CONTEXT" > /dev/null 2>&1
    exit 1
fi

# Test 2: Delete entire subject
echo -e "${YELLOW}[TEST] Delete entire subject...${NC}"

# Delete the subject
if ! $CLI delete subject "$TEST_SUBJECT" --context "$TEST_CONTEXT" > /dev/null; then
    echo -e "${RED}✗ FAILED: Failed to delete subject${NC}"
    $CLI config delete-context "$TEST_CONTEXT" > /dev/null 2>&1
    exit 1
fi

# Print output for debugging
GET_VERSIONS_OUTPUT=$($CLI get versions "$TEST_SUBJECT" --context "$TEST_CONTEXT" 2>&1)
echo -e "[DEBUG] Output of get versions after subject deletion:\n$GET_VERSIONS_OUTPUT"

# Verify subject was deleted
if ! echo "$GET_VERSIONS_OUTPUT" | grep -iq "not found"; then
    echo -e "${RED}✗ FAILED: Subject still exists after deletion${NC}"
    $CLI config delete-context "$TEST_CONTEXT" > /dev/null 2>&1
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Successfully deleted subject${NC}"
fi

# Test 3: Delete non-existent version
echo -e "${YELLOW}[TEST] Delete non-existent version...${NC}"

# Try to delete a non-existent version
if $CLI delete version "$TEST_SUBJECT" --version 999 --context "$TEST_CONTEXT" 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed when deleting non-existent version${NC}"
    $CLI config delete-context "$TEST_CONTEXT" > /dev/null 2>&1
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled non-existent version${NC}"
fi

# Test 4: Delete non-existent subject
echo -e "${YELLOW}[TEST] Delete non-existent subject...${NC}"

# Try to delete a non-existent subject
if $CLI delete subject "non-existent-subject" --context "$TEST_CONTEXT" 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed when deleting non-existent subject${NC}"
    $CLI config delete-context "$TEST_CONTEXT" > /dev/null 2>&1
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled non-existent subject${NC}"
fi

# Cleanup
rm -f schema1.json schema2.json
$CLI config delete-context "$TEST_CONTEXT" > /dev/null 2>&1

echo -e "${GREEN}All delete command tests passed!${NC}" 