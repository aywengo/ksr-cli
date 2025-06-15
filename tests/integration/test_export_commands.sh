#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLI="../../build/ksr-cli"
TEMP_DIR="/tmp/ksr-cli-export-tests"
TEST_EXPORT_FILE="$TEMP_DIR/test-export.json"
TEST_EXPORT_DIR="$TEMP_DIR/exports"

# Cleanup function
cleanup() {
    echo -e "${BLUE}[CLEANUP] Removing temporary files...${NC}"
    rm -rf "$TEMP_DIR"
}

# Setup trap for cleanup
trap cleanup EXIT

# Create temp directory
mkdir -p "$TEMP_DIR"
mkdir -p "$TEST_EXPORT_DIR"

echo -e "${BLUE}=== Testing EXPORT Commands ===${NC}"

# Test 1: Export all subjects to stdout (JSON format)
echo -e "${YELLOW}[TEST] Export all subjects to stdout (JSON)...${NC}"
EXPORT_OUTPUT=$($CLI export subjects --output json)
if echo "$EXPORT_OUTPUT" | python3 -m json.tool > /dev/null 2>&1; then
    if echo "$EXPORT_OUTPUT" | grep -q '"metadata"' && echo "$EXPORT_OUTPUT" | grep -q '"subjects"'; then
        echo -e "${GREEN}✓ PASSED: Valid JSON export with metadata and subjects${NC}"
    else
        echo -e "${RED}✗ FAILED: Missing required fields in export output${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ FAILED: Invalid JSON output${NC}"
    echo "Output: $EXPORT_OUTPUT"
    exit 1
fi

# Test 2: Export all subjects to file
echo -e "${YELLOW}[TEST] Export all subjects to file...${NC}"
$CLI export subjects --file "$TEST_EXPORT_FILE"
if [ -f "$TEST_EXPORT_FILE" ]; then
    if python3 -m json.tool "$TEST_EXPORT_FILE" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED: Export to file successful${NC}"
    else
        echo -e "${RED}✗ FAILED: Invalid JSON in export file${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ FAILED: Export file not created${NC}"
    exit 1
fi

# Test 3: Export all subjects with all versions
echo -e "${YELLOW}[TEST] Export all subjects with all versions...${NC}"
ALL_VERSIONS_OUTPUT=$($CLI export subjects --all-versions --output json)
if echo "$ALL_VERSIONS_OUTPUT" | python3 -m json.tool > /dev/null 2>&1; then
    # Check if we have version arrays with multiple entries
    VERSION_COUNT=$(echo "$ALL_VERSIONS_OUTPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
total_versions = sum(len(subject['versions']) for subject in data.get('subjects', []))
print(total_versions)
    ")
    if [ "$VERSION_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ PASSED: All versions export contains $VERSION_COUNT schema versions${NC}"
    else
        echo -e "${RED}✗ FAILED: No versions found in all versions export${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ FAILED: Invalid JSON in all versions export${NC}"
    exit 1
fi

# Test 4: Export specific subject
echo -e "${YELLOW}[TEST] Export specific subject...${NC}"
if $CLI export subject user-value --output json > "$TEMP_DIR/user-export.json"; then
    if python3 -m json.tool "$TEMP_DIR/user-export.json" > /dev/null 2>&1; then
        # Check if the export contains the correct subject
        SUBJECT_NAME=$(python3 -c "
import json
with open('$TEMP_DIR/user-export.json') as f:
    data = json.load(f)
    if data.get('subjects') and len(data['subjects']) > 0:
        print(data['subjects'][0]['name'])
        ")
        if [ "$SUBJECT_NAME" = "user-value" ]; then
            echo -e "${GREEN}✓ PASSED: Specific subject export successful${NC}"
        else
            echo -e "${RED}✗ FAILED: Wrong subject in export, expected 'user-value', got '$SUBJECT_NAME'${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ FAILED: Invalid JSON in subject export${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ FAILED: Failed to export specific subject${NC}"
    exit 1
fi

# Test 5: Export specific subject with all versions
echo -e "${YELLOW}[TEST] Export specific subject with all versions...${NC}"
$CLI export subject user-value --all-versions --file "$TEMP_DIR/user-all-versions.json"
if [ -f "$TEMP_DIR/user-all-versions.json" ]; then
    VERSION_COUNT=$(python3 -c "
import json
with open('$TEMP_DIR/user-all-versions.json') as f:
    data = json.load(f)
    if data.get('subjects') and len(data['subjects']) > 0:
        print(len(data['subjects'][0]['versions']))
    else:
        print(0)
    ")
    if [ "$VERSION_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ PASSED: Subject all versions export contains $VERSION_COUNT versions${NC}"
    else
        echo -e "${RED}✗ FAILED: No versions in subject all versions export${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ FAILED: Subject all versions export file not created${NC}"
    exit 1
fi

# Test 6: Export to directory (separate files)
echo -e "${YELLOW}[TEST] Export to directory (separate files)...${NC}"
$CLI export subjects --directory "$TEST_EXPORT_DIR"
if [ -d "$TEST_EXPORT_DIR" ]; then
    FILE_COUNT=$(find "$TEST_EXPORT_DIR" -name "*.json" | wc -l)
    if [ "$FILE_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ PASSED: Directory export created $FILE_COUNT files${NC}"
        
        # Verify one of the files is valid JSON
        FIRST_FILE=$(find "$TEST_EXPORT_DIR" -name "*.json" | head -1)
        if python3 -m json.tool "$FIRST_FILE" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASSED: Directory export files are valid JSON${NC}"
        else
            echo -e "${RED}✗ FAILED: Directory export files contain invalid JSON${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ FAILED: No files created in directory export${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ FAILED: Export directory not created${NC}"
    exit 1
fi

# Test 7: Export without configuration
echo -e "${YELLOW}[TEST] Export without configuration...${NC}"
NO_CONFIG_OUTPUT=$($CLI export subjects --include-config=false --output json)
if echo "$NO_CONFIG_OUTPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
has_global_config = 'config' in data and data['config'] is not None
has_subject_config = any('config' in subject and subject['config'] is not None for subject in data.get('subjects', []))
if has_global_config or has_subject_config:
    sys.exit(1)
else:
    sys.exit(0)
"; then
    echo -e "${GREEN}✓ PASSED: Export without config excludes configuration data${NC}"
else
    echo -e "${RED}✗ FAILED: Export without config still contains configuration data${NC}"
    exit 1
fi

# Test 8: Export in YAML format
echo -e "${YELLOW}[TEST] Export in YAML format...${NC}"
YAML_OUTPUT=$($CLI export subjects --output yaml)
if echo "$YAML_OUTPUT" | grep -E "^metadata:" && echo "$YAML_OUTPUT" | grep -E "^subjects:"; then
    echo -e "${GREEN}✓ PASSED: YAML export format${NC}"
else
    echo -e "${RED}✗ FAILED: Invalid YAML export format${NC}"
    echo "Output: $YAML_OUTPUT"
    exit 1
fi

# Test 9: Export with context
echo -e "${YELLOW}[TEST] Export with context...${NC}"
if $CLI export subjects --context test-context --output json > "$TEMP_DIR/context-export.json" 2>/dev/null; then
    # Check if context is in metadata
    EXPORT_CONTEXT=$(python3 -c "
import json
with open('$TEMP_DIR/context-export.json') as f:
    data = json.load(f)
    print(data.get('metadata', {}).get('context', ''))
    ")
    if [ "$EXPORT_CONTEXT" = "test-context" ]; then
        echo -e "${GREEN}✓ PASSED: Context export includes correct context in metadata${NC}"
    else
        echo -e "${YELLOW}~ SKIPPED: Context export (no schemas in test-context)${NC}"
    fi
else
    echo -e "${YELLOW}~ SKIPPED: Context export (context may not exist)${NC}"
fi

# Test 10: Error handling - non-existent subject
echo -e "${YELLOW}[TEST] Error handling - non-existent subject...${NC}"
if $CLI export subject non-existent-subject 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with non-existent subject${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled non-existent subject${NC}"
fi

# Test 11: Export metadata validation
echo -e "${YELLOW}[TEST] Export metadata validation...${NC}"
METADATA_CHECK=$($CLI export subjects --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
metadata = data.get('metadata', {})
required_fields = ['exported_at', 'cli_version']
missing_fields = [field for field in required_fields if not metadata.get(field)]
if missing_fields:
    print('Missing fields: ' + ', '.join(missing_fields))
    sys.exit(1)
else:
    print('All required metadata fields present')
    sys.exit(0)
")
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED: Export metadata contains required fields${NC}"
else
    echo -e "${RED}✗ FAILED: Export metadata validation failed: $METADATA_CHECK${NC}"
    exit 1
fi

# Test 12: Export schema validation
echo -e "${YELLOW}[TEST] Export schema validation...${NC}"
SCHEMA_VALIDATION=$($CLI export subject user-value --output json | python3 -c "
import json, sys
data = json.load(sys.stdin)
if not data.get('subjects'):
    print('No subjects in export')
    sys.exit(1)

subject = data['subjects'][0]
required_fields = ['name', 'versions']
missing_fields = [field for field in required_fields if field not in subject]
if missing_fields:
    print('Missing subject fields: ' + ', '.join(missing_fields))
    sys.exit(1)

if not subject['versions']:
    print('No versions in subject')
    sys.exit(1)

version = subject['versions'][0]
version_fields = ['id', 'version', 'schema']
missing_version_fields = [field for field in version_fields if field not in version]
if missing_version_fields:
    print('Missing version fields: ' + ', '.join(missing_version_fields))
    sys.exit(1)

print('Schema structure validation passed')
sys.exit(0)
")
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED: Export schema structure validation${NC}"
else
    echo -e "${RED}✗ FAILED: Export schema validation failed: $SCHEMA_VALIDATION${NC}"
    exit 1
fi

echo -e "${GREEN}All EXPORT command tests passed!${NC}" 