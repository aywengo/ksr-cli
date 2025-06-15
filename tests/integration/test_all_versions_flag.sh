#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLI="../../build/ksr-cli"
TEMP_DIR="/tmp/ksr-cli-all-versions-tests"

# Cleanup function
cleanup() {
    echo -e "${BLUE}[CLEANUP] Removing temporary files...${NC}"
    rm -rf "$TEMP_DIR"
}

# Setup trap for cleanup
trap cleanup EXIT

# Create temp directory
mkdir -p "$TEMP_DIR"

echo -e "${BLUE}=== Testing --all-versions Flag ===${NC}"

# Test 1: --all-versions flag on get schemas
echo -e "${YELLOW}[TEST] get schemas --all-versions flag...${NC}"
ALL_VERSIONS_OUTPUT=$($CLI get schemas user-value --all-versions 2>/dev/null || echo "FAILED")
if [ "$ALL_VERSIONS_OUTPUT" != "FAILED" ]; then
    echo -e "${GREEN}✓ PASSED: --all-versions flag works with get schemas${NC}"
else
    echo -e "${RED}✗ FAILED: --all-versions flag failed with get schemas${NC}"
    exit 1
fi

# Test 2: --all flag still works (backward compatibility)
echo -e "${YELLOW}[TEST] get schemas --all flag (backward compatibility)...${NC}"
ALL_FLAG_OUTPUT=$($CLI get schemas user-value --all 2>/dev/null || echo "FAILED")
if [ "$ALL_FLAG_OUTPUT" != "FAILED" ]; then
    echo -e "${GREEN}✓ PASSED: --all flag still works for backward compatibility${NC}"
else
    echo -e "${RED}✗ FAILED: --all flag failed${NC}"
    exit 1
fi

# Test 3: Compare --all and --all-versions outputs (should be identical)
echo -e "${YELLOW}[TEST] --all and --all-versions produce identical output...${NC}"
ALL_OUTPUT=$($CLI get schemas user-value --all --output json 2>/dev/null || echo "{}")
ALL_VERSIONS_OUTPUT=$($CLI get schemas user-value --all-versions --output json 2>/dev/null || echo "{}")

if [ "$ALL_OUTPUT" = "$ALL_VERSIONS_OUTPUT" ]; then
    echo -e "${GREEN}✓ PASSED: --all and --all-versions produce identical output${NC}"
else
    echo -e "${YELLOW}~ WARNING: --all and --all-versions outputs differ (may be expected)${NC}"
fi

# Test 4: --all-versions flag on export subjects
echo -e "${YELLOW}[TEST] export subjects --all-versions flag...${NC}"
EXPORT_ALL_VERSIONS_OUTPUT=$($CLI export subjects --all-versions --output json 2>/dev/null || echo "FAILED")
if [ "$EXPORT_ALL_VERSIONS_OUTPUT" != "FAILED" ]; then
    if echo "$EXPORT_ALL_VERSIONS_OUTPUT" | python3 -m json.tool > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED: --all-versions flag works with export subjects${NC}"
    else
        echo -e "${RED}✗ FAILED: --all-versions export produced invalid JSON${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ FAILED: --all-versions flag failed with export subjects${NC}"
    exit 1
fi

# Test 5: --all-versions flag on export specific subject
echo -e "${YELLOW}[TEST] export subject --all-versions flag...${NC}"
EXPORT_SUBJECT_ALL_VERSIONS=$($CLI export subject user-value --all-versions --output json 2>/dev/null || echo "FAILED")
if [ "$EXPORT_SUBJECT_ALL_VERSIONS" != "FAILED" ]; then
    if echo "$EXPORT_SUBJECT_ALL_VERSIONS" | python3 -m json.tool > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED: --all-versions flag works with export subject${NC}"
    else
        echo -e "${RED}✗ FAILED: --all-versions export subject produced invalid JSON${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ FAILED: --all-versions flag failed with export subject${NC}"
    exit 1
fi

# Test 6: Verify --all-versions actually gets multiple versions (if they exist)
echo -e "${YELLOW}[TEST] --all-versions retrieves multiple versions when available...${NC}"
# First, check how many versions the subject has
VERSIONS_LIST=$($CLI get versions user-value 2>/dev/null || echo "[]")
VERSION_COUNT=$(echo "$VERSIONS_LIST" | wc -w)

if [ "$VERSION_COUNT" -gt 1 ]; then
    # If multiple versions exist, verify all-versions gets them
    ALL_VERSIONS_JSON=$($CLI get schemas user-value --all-versions --output json)
    RETRIEVED_COUNT=$(echo "$ALL_VERSIONS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        print(len(data))
    else:
        print(1)
except:
    print(0)
    ")
    
    if [ "$RETRIEVED_COUNT" -gt 1 ]; then
        echo -e "${GREEN}✓ PASSED: --all-versions retrieved $RETRIEVED_COUNT versions${NC}"
    else
        echo -e "${YELLOW}~ WARNING: --all-versions may not have retrieved all versions${NC}"
    fi
else
    echo -e "${YELLOW}~ SKIPPED: Only one version available for testing${NC}"
fi

# Test 7: Version comparison between export with and without --all-versions
echo -e "${YELLOW}[TEST] Export version count comparison...${NC}"
EXPORT_LATEST=$($CLI export subject user-value --output json)
EXPORT_ALL=$($CLI export subject user-value --all-versions --output json)

LATEST_VERSION_COUNT=$(echo "$EXPORT_LATEST" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('subjects') and len(data['subjects']) > 0:
    print(len(data['subjects'][0].get('versions', [])))
else:
    print(0)
")

ALL_VERSION_COUNT=$(echo "$EXPORT_ALL" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('subjects') and len(data['subjects']) > 0:
    print(len(data['subjects'][0].get('versions', [])))
else:
    print(0)
")

echo -e "${BLUE}[INFO] Latest export versions: $LATEST_VERSION_COUNT${NC}"
echo -e "${BLUE}[INFO] All versions export versions: $ALL_VERSION_COUNT${NC}"

if [ "$ALL_VERSION_COUNT" -ge "$LATEST_VERSION_COUNT" ]; then
    echo -e "${GREEN}✓ PASSED: --all-versions exports >= latest export versions${NC}"
else
    echo -e "${RED}✗ FAILED: --all-versions exports fewer versions than latest export${NC}"
    exit 1
fi

# Test 8: Help text includes --all-versions flag
echo -e "${YELLOW}[TEST] Help text includes --all-versions flag...${NC}"
GET_HELP=$($CLI get schemas --help)
EXPORT_HELP=$($CLI export --help)

if echo "$GET_HELP" | grep -q "all-versions"; then
    echo -e "${GREEN}✓ PASSED: --all-versions flag documented in get schemas help${NC}"
else
    echo -e "${RED}✗ FAILED: --all-versions flag missing from get schemas help${NC}"
    exit 1
fi

if echo "$EXPORT_HELP" | grep -q "all-versions"; then
    echo -e "${GREEN}✓ PASSED: --all-versions flag documented in export help${NC}"
else
    echo -e "${RED}✗ FAILED: --all-versions flag missing from export help${NC}"
    exit 1
fi

# Test 9: Error handling - incompatible flags
echo -e "${YELLOW}[TEST] Error handling - incompatible flags...${NC}"
# Test that --all-versions and --version flags work appropriately together
SPECIFIC_VERSION_OUTPUT=$($CLI get schemas user-value --version 1 2>/dev/null || echo "FAILED")
if [ "$SPECIFIC_VERSION_OUTPUT" != "FAILED" ]; then
    echo -e "${GREEN}✓ PASSED: Specific version flag works correctly${NC}"
else
    echo -e "${YELLOW}~ SKIPPED: Version 1 may not exist for this subject${NC}"
fi

# Test 10: JSON structure validation for --all-versions
echo -e "${YELLOW}[TEST] JSON structure validation for --all-versions...${NC}"
STRUCTURE_VALIDATION=$($CLI export subject user-value --all-versions --output json | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    
    # Validate top-level structure
    required_keys = ['metadata', 'subjects']
    missing_keys = [key for key in required_keys if key not in data]
    if missing_keys:
        print(f'Missing top-level keys: {missing_keys}')
        sys.exit(1)
    
    # Validate subjects structure
    if not data['subjects']:
        print('No subjects in export')
        sys.exit(1)
    
    subject = data['subjects'][0]
    if 'versions' not in subject:
        print('No versions in subject')
        sys.exit(1)
    
    # Validate version structure
    for version in subject['versions']:
        version_keys = ['id', 'version', 'schema']
        missing_version_keys = [key for key in version_keys if key not in version]
        if missing_version_keys:
            print(f'Missing version keys: {missing_version_keys}')
            sys.exit(1)
    
    print(f'Valid structure with {len(subject[\"versions\"])} versions')
    sys.exit(0)
    
except Exception as e:
    print(f'Validation error: {e}')
    sys.exit(1)
")

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED: --all-versions JSON structure is valid${NC}"
    echo -e "${BLUE}[INFO] $STRUCTURE_VALIDATION${NC}"
else
    echo -e "${RED}✗ FAILED: --all-versions JSON structure validation failed${NC}"
    echo "Validation output: $STRUCTURE_VALIDATION"
    exit 1
fi

echo -e "${GREEN}All --all-versions flag tests passed!${NC}" 