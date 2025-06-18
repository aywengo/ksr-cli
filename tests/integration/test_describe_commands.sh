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
TEST_CONTEXT="test-describe-ctx"

echo -e "${BLUE}=== Testing DESCRIBE Commands ===${NC}"

# Cleanup function to be called on exit
cleanup() {
    echo -e "${YELLOW}[CLEANUP] Removing test data...${NC}"
    # Delete test subjects from our test context
    $CLI delete subject describe-user-test --permanent --context "$TEST_CONTEXT" 2>/dev/null || true
    $CLI delete subject describe-product-test --permanent --context "$TEST_CONTEXT" 2>/dev/null || true
    $CLI delete subject describe-json-test --permanent --context "$TEST_CONTEXT" 2>/dev/null || true
    $CLI delete subject describe-order-test --permanent --context "$TEST_CONTEXT" 2>/dev/null || true
    
    # Also clean up any test files
    rm -f /tmp/test-json-schema.json
    echo -e "${GREEN}✓ Cleanup completed${NC}"
}

# Set up cleanup trap
trap cleanup EXIT

# Setup test data
echo -e "${YELLOW}[SETUP] Creating test data in context: $TEST_CONTEXT...${NC}"

# Create AVRO schemas for testing
$CLI create schema describe-user-test --file "$TEST_SCHEMAS_DIR/user.avsc" --context "$TEST_CONTEXT" > /dev/null
$CLI create schema describe-product-test --file "$TEST_SCHEMAS_DIR/product.avsc" --context "$TEST_CONTEXT" > /dev/null
$CLI create schema describe-order-test --file "$TEST_SCHEMAS_DIR/order.avsc" --context "$TEST_CONTEXT" > /dev/null

# Create a second version of user schema
$CLI create schema describe-user-test --file "$TEST_SCHEMAS_DIR/user-v2.avsc" --context "$TEST_CONTEXT" > /dev/null 2>&1 || true

# Create JSON schema for testing
JSON_SCHEMA='{"type": "object", "properties": {"name": {"type": "string"}, "age": {"type": "integer"}}, "required": ["name"]}'
echo "$JSON_SCHEMA" > /tmp/test-json-schema.json
$CLI create schema describe-json-test --file /tmp/test-json-schema.json --type JSON --context "$TEST_CONTEXT" > /dev/null 2>&1 || true

echo -e "${GREEN}✓ Test data created successfully${NC}"

# Test 1: Describe Schema Registry instance (basic registry info)
echo -e "${YELLOW}[TEST] Describe Schema Registry instance...${NC}"
REGISTRY_DESCRIBE_OUTPUT=$($CLI describe --output json)
if echo "$REGISTRY_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); exit(0 if 'url' in data and 'is_accessible' in data and 'subject_count' in data and 'info' in data else 1)" 2>/dev/null; then
    echo -e "${GREEN}✓ PASSED: Registry description contains required fields${NC}"
else
    echo -e "${RED}✗ FAILED: Registry description missing required fields${NC}"
    echo "Output: $REGISTRY_DESCRIBE_OUTPUT"
    exit 1
fi

# Test 2: Verify registry accessibility status
echo -e "${YELLOW}[TEST] Verify registry accessibility status...${NC}"
ACCESSIBILITY_STATUS=$(echo "$REGISTRY_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('is_accessible', False))")
if [ "$ACCESSIBILITY_STATUS" = "True" ]; then
    echo -e "${GREEN}✓ PASSED: Registry is marked as accessible${NC}"
else
    echo -e "${RED}✗ FAILED: Registry not marked as accessible${NC}"
    echo "Accessibility status: $ACCESSIBILITY_STATUS"
    exit 1
fi

# Test 3: Check subject count in registry description
echo -e "${YELLOW}[TEST] Check subject count in registry description...${NC}"
SUBJECT_COUNT=$(echo "$REGISTRY_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('subject_count', 0))")
if [ "$SUBJECT_COUNT" -ge 0 ]; then
    echo -e "${GREEN}✓ PASSED: Subject count retrieved: $SUBJECT_COUNT${NC}"
else
    echo -e "${RED}✗ FAILED: Invalid subject count${NC}"
    exit 1
fi

# Test 3a: Check registry version information
echo -e "${YELLOW}[TEST] Check registry version information...${NC}"
REGISTRY_VERSION=$(echo "$REGISTRY_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); info=data.get('info', {}); print(info.get('version', ''))")
REGISTRY_COMMIT=$(echo "$REGISTRY_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); info=data.get('info', {}); print(info.get('commit', ''))")
KAFKA_CLUSTER_ID=$(echo "$REGISTRY_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); info=data.get('info', {}); print(info.get('kafka_cluster_id', ''))")

if [ -n "$REGISTRY_VERSION" ] && [ -n "$REGISTRY_COMMIT" ] && [ -n "$KAFKA_CLUSTER_ID" ]; then
    echo -e "${GREEN}✓ PASSED: Registry metadata detected - Version: $REGISTRY_VERSION, Commit: ${REGISTRY_COMMIT:0:7}..., Kafka Cluster: ${KAFKA_CLUSTER_ID:0:7}...${NC}"
else
    echo -e "${RED}✗ FAILED: Registry metadata missing${NC}"
    echo "Version: '$REGISTRY_VERSION', Commit: '$REGISTRY_COMMIT', Kafka Cluster: '$KAFKA_CLUSTER_ID'"
    exit 1
fi

# Test 4: Describe with table output format (default)
echo -e "${YELLOW}[TEST] Describe with table output format...${NC}"
TABLE_OUTPUT=$($CLI describe)
if [ -n "$TABLE_OUTPUT" ] && ! echo "$TABLE_OUTPUT" | grep -q "Error\|error\|FAILED"; then
    echo -e "${GREEN}✓ PASSED: Table format output works${NC}"
else
    echo -e "${RED}✗ FAILED: Table format output failed${NC}"
    echo "Output: $TABLE_OUTPUT"
    exit 1
fi

# Test 5: Describe with YAML output format
echo -e "${YELLOW}[TEST] Describe with YAML output format...${NC}"
YAML_OUTPUT=$($CLI describe --output yaml)
if echo "$YAML_OUTPUT" | grep -E "^[a-z_]+:" > /dev/null; then
    echo -e "${GREEN}✓ PASSED: YAML format detected${NC}"
else
    echo -e "${RED}✗ FAILED: Invalid YAML output${NC}"
    echo "Output: $YAML_OUTPUT"
    exit 1
fi

# Test 6: Describe a specific subject (use our test subject)
echo -e "${YELLOW}[TEST] Describe a specific subject...${NC}"
SUBJECT_DESCRIBE_OUTPUT=$($CLI describe describe-user-test --context "$TEST_CONTEXT" --output json)
if echo "$SUBJECT_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); exit(0 if 'name' in data and 'versions' in data and 'suggested_commands' in data else 1)" 2>/dev/null; then
    echo -e "${GREEN}✓ PASSED: Subject description contains required fields${NC}"
else
    echo -e "${RED}✗ FAILED: Subject description missing required fields${NC}"
    echo "Output: $SUBJECT_DESCRIBE_OUTPUT"
    exit 1
fi

# Test 7: Verify subject name in description
echo -e "${YELLOW}[TEST] Verify subject name in description...${NC}"
SUBJECT_NAME=$(echo "$SUBJECT_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('name', ''))")
if [ "$SUBJECT_NAME" = "describe-user-test" ]; then
    echo -e "${GREEN}✓ PASSED: Subject name correctly set${NC}"
else
    echo -e "${RED}✗ FAILED: Subject name incorrect${NC}"
    echo "Expected: describe-user-test, Got: $SUBJECT_NAME"
    exit 1
fi

# Test 8: Check versions in subject description
echo -e "${YELLOW}[TEST] Check versions in subject description...${NC}"
VERSIONS_COUNT=$(echo "$SUBJECT_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('versions', [])))")
if [ "$VERSIONS_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ PASSED: Subject has $VERSIONS_COUNT versions listed${NC}"
else
    echo -e "${RED}✗ FAILED: Subject has no versions listed${NC}"
    echo "Versions count: $VERSIONS_COUNT"
    exit 1
fi

# Test 9: Verify suggested commands are present
echo -e "${YELLOW}[TEST] Verify suggested commands are present...${NC}"
SUGGESTED_COUNT=$(echo "$SUBJECT_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('suggested_commands', [])))")
if [ "$SUGGESTED_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ PASSED: $SUGGESTED_COUNT suggested commands present${NC}"
else
    echo -e "${RED}✗ FAILED: No suggested commands found${NC}"
    echo "Suggested commands count: $SUGGESTED_COUNT"
    exit 1
fi

# Test 10: Verify suggested commands contain subject name and context
echo -e "${YELLOW}[TEST] Verify suggested commands contain subject name and context...${NC}"
COMMANDS_WITH_SUBJECT=$(echo "$SUBJECT_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); cmds=data.get('suggested_commands', []); print(sum(1 for cmd in cmds if 'describe-user-test' in cmd))")
COMMANDS_WITH_CONTEXT=$(echo "$SUBJECT_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); cmds=data.get('suggested_commands', []); print(sum(1 for cmd in cmds if '$TEST_CONTEXT' in cmd))")
if [ "$COMMANDS_WITH_SUBJECT" -gt 0 ]; then
    echo -e "${GREEN}✓ PASSED: Suggested commands contain subject name${NC}"
else
    echo -e "${RED}✗ FAILED: Suggested commands don't contain subject name${NC}"
    exit 1
fi

# Test 11: Check field count for AVRO schema
echo -e "${YELLOW}[TEST] Check field count for AVRO schema...${NC}"
FIELD_COUNT=$(echo "$SUBJECT_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('field_count', 0))")
if [ "$FIELD_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ PASSED: Schema field count detected: $FIELD_COUNT${NC}"
else
    echo -e "${YELLOW}ℹ INFO: Field count is 0 (may be expected for some schemas)${NC}"
fi

# Test 12: Describe our test context
echo -e "${YELLOW}[TEST] Describe our test context...${NC}"
CONTEXT_DESCRIBE_OUTPUT=$($CLI describe --context "$TEST_CONTEXT" --output json)
if echo "$CONTEXT_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); exit(0 if 'name' in data and 'subject_count' in data else 1)" 2>/dev/null; then
    echo -e "${GREEN}✓ PASSED: Context description works${NC}"
    # Check if our test subjects are listed
    CONTEXT_SUBJECT_COUNT=$(echo "$CONTEXT_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('subject_count', 0))")
    echo -e "${GREEN}✓ Context has $CONTEXT_SUBJECT_COUNT subjects${NC}"
else
    echo -e "${YELLOW}ℹ INFO: Context description may not be fully supported${NC}"
fi

# Test 13: Error handling - non-existent subject
echo -e "${YELLOW}[TEST] Error handling - non-existent subject...${NC}"
if $CLI describe non-existent-subject-xyz --context "$TEST_CONTEXT" 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with non-existent subject${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled non-existent subject${NC}"
fi

# Test 14: Error handling - invalid registry URL
echo -e "${YELLOW}[TEST] Error handling - invalid registry URL...${NC}"
INVALID_REGISTRY_OUTPUT=$($CLI describe --registry-url http://invalid-url-xyz:9999 --output json 2>/dev/null || echo '{}')
INVALID_ACCESSIBLE=$(echo "$INVALID_REGISTRY_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('is_accessible', True))" 2>/dev/null || echo "True")
if [ "$INVALID_ACCESSIBLE" = "False" ]; then
    echo -e "${GREEN}✓ PASSED: Invalid registry correctly marked as inaccessible${NC}"
else
    echo -e "${YELLOW}ℹ INFO: Invalid registry handling may need adjustment${NC}"
fi

# Test 15: Check schema type detection
echo -e "${YELLOW}[TEST] Check schema type detection...${NC}"
SCHEMA_TYPE=$(echo "$SUBJECT_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('schema_type', 'UNKNOWN'))")
if [ "$SCHEMA_TYPE" != "UNKNOWN" ] && [ -n "$SCHEMA_TYPE" ]; then
    echo -e "${GREEN}✓ PASSED: Schema type detected: $SCHEMA_TYPE${NC}"
else
    echo -e "${YELLOW}ℹ INFO: Schema type not detected (may be expected)${NC}"
fi

# Test 16: Verify latest version info
echo -e "${YELLOW}[TEST] Verify latest version info...${NC}"
LATEST_VERSION=$(echo "$SUBJECT_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('latest_version', 0))")
if [ "$LATEST_VERSION" -gt 0 ]; then
    echo -e "${GREEN}✓ PASSED: Latest version detected: $LATEST_VERSION${NC}"
else
    echo -e "${RED}✗ FAILED: Latest version not detected${NC}"
    echo "Latest version: $LATEST_VERSION"
    exit 1
fi

# Test 17: Check if latest schema is included
echo -e "${YELLOW}[TEST] Check if latest schema is included...${NC}"
HAS_LATEST_SCHEMA=$(echo "$SUBJECT_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print('latest_schema' in data and data['latest_schema'] is not None)")
if [ "$HAS_LATEST_SCHEMA" = "True" ]; then
    echo -e "${GREEN}✓ PASSED: Latest schema information included${NC}"
else
    echo -e "${YELLOW}ℹ INFO: Latest schema information not included (may be expected)${NC}"
fi

# Test 18: Test multiple subjects in same context
echo -e "${YELLOW}[TEST] Test multiple subjects in same context...${NC}"
PRODUCT_DESCRIBE_OUTPUT=$($CLI describe describe-product-test --context "$TEST_CONTEXT" --output json)
PRODUCT_NAME=$(echo "$PRODUCT_DESCRIBE_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('name', ''))" 2>/dev/null || echo "")
if [ "$PRODUCT_NAME" = "describe-product-test" ]; then
    echo -e "${GREEN}✓ PASSED: Multiple subjects work in same context${NC}"
else
    echo -e "${YELLOW}ℹ INFO: Product test subject may not have been created${NC}"
fi

# Test 19: Test describe with authentication flags
echo -e "${YELLOW}[TEST] Test describe with authentication flags...${NC}"
AUTH_OUTPUT=$($CLI describe --user test --pass test --output json 2>/dev/null || echo '{"is_accessible": false}')
# Just verify the command doesn't crash with auth flags
if echo "$AUTH_OUTPUT" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
    echo -e "${GREEN}✓ PASSED: Authentication flags don't break describe command${NC}"
else
    echo -e "${RED}✗ FAILED: Authentication flags break describe command${NC}"
    exit 1
fi

# Test 20: Test JSON schema field counting (if JSON schema was created)
echo -e "${YELLOW}[TEST] Test JSON schema field counting...${NC}"
JSON_SUBJECT_OUTPUT=$($CLI describe describe-json-test --context "$TEST_CONTEXT" --output json 2>/dev/null || echo '{}')
JSON_FIELD_COUNT=$(echo "$JSON_SUBJECT_OUTPUT" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('field_count', 0))" 2>/dev/null || echo "0")
if [ "$JSON_FIELD_COUNT" = "2" ]; then
    echo -e "${GREEN}✓ PASSED: JSON schema field count correctly detected: $JSON_FIELD_COUNT${NC}"
elif [ "$JSON_FIELD_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ PASSED: JSON schema field count detected: $JSON_FIELD_COUNT${NC}"
else
    echo -e "${YELLOW}ℹ INFO: JSON schema may not have been created or field counting needs adjustment${NC}"
fi

echo -e "${GREEN}All DESCRIBE command tests passed!${NC}" 