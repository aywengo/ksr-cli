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

echo -e "${BLUE}=== Testing CREATE Commands ===${NC}"

# Test 1: Create schema from file
echo -e "${YELLOW}[TEST] Create schema from file...${NC}"
if $CLI create schema product-value --file "$TEST_SCHEMAS_DIR/product.avsc"; then
    echo -e "${GREEN}✓ PASSED: Schema created from file${NC}"
else
    echo -e "${RED}✗ FAILED: Schema creation from file failed${NC}"
    exit 1
fi

# Test 2: Create schema with inline JSON
echo -e "${YELLOW}[TEST] Create schema with inline JSON...${NC}"
INLINE_SCHEMA='{"type":"record","name":"SimpleRecord","fields":[{"name":"id","type":"int"},{"name":"name","type":"string"}]}'
if $CLI create schema simple-inline-value --schema "$INLINE_SCHEMA"; then
    echo -e "${GREEN}✓ PASSED: Schema created with inline JSON${NC}"
else
    echo -e "${RED}✗ FAILED: Schema creation with inline JSON failed${NC}"
    exit 1
fi

# Test 3: Create JSON schema type
echo -e "${YELLOW}[TEST] Create JSON schema type...${NC}"
if $CLI create schema simple-message-value --file "$TEST_SCHEMAS_DIR/simple-string.json" --type JSON; then
    echo -e "${GREEN}✓ PASSED: JSON schema type created${NC}"
else
    echo -e "${RED}✗ FAILED: JSON schema type creation failed${NC}"
    exit 1
fi

# Test 4: Create schema with context
echo -e "${YELLOW}[TEST] Create schema with context...${NC}"
if $CLI create schema product-test-value --file "$TEST_SCHEMAS_DIR/product.avsc" --context test-context; then
    echo -e "${GREEN}✓ PASSED: Schema created with context${NC}"
else
    echo -e "${RED}✗ FAILED: Schema creation with context failed${NC}"
    exit 1
fi

# Test 5: Create schema from stdin
echo -e "${YELLOW}[TEST] Create schema from stdin...${NC}"
if cat "$TEST_SCHEMAS_DIR/user.avsc" | $CLI create schema user-stdin-value; then
    echo -e "${GREEN}✓ PASSED: Schema created from stdin${NC}"
else
    echo -e "${RED}✗ FAILED: Schema creation from stdin failed${NC}"
    exit 1
fi

# Test 6: Error handling - invalid schema
echo -e "${YELLOW}[TEST] Error handling - invalid schema...${NC}"
if $CLI create schema invalid-test-value --file "$TEST_SCHEMAS_DIR/invalid-schema.json" 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with invalid schema${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled invalid schema${NC}"
fi

# Test 7: Error handling - missing file
echo -e "${YELLOW}[TEST] Error handling - missing file...${NC}"
if $CLI create schema missing-file-value --file "nonexistent.avsc" 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with missing file${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled missing file${NC}"
fi

# Test 8: Create second version of existing schema
echo -e "${YELLOW}[TEST] Create second version of existing schema...${NC}"
if $CLI create schema user-value --file "$TEST_SCHEMAS_DIR/user-v2.avsc"; then
    echo -e "${GREEN}✓ PASSED: Second version created${NC}"
else
    echo -e "${RED}✗ FAILED: Second version creation failed${NC}"
    exit 1
fi

echo -e "${GREEN}All CREATE command tests passed!${NC}" 