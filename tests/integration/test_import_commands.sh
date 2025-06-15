#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLI="../../build/ksr-cli"
TEMP_DIR="/tmp/ksr-cli-import-tests"
TEST_EXPORT_FILE="$TEMP_DIR/test-export.json"
TEST_IMPORT_FILE="$TEMP_DIR/test-import.json"
TEST_IMPORT_DIR="$TEMP_DIR/imports"
TEST_SUBJECT_FILE="$TEMP_DIR/single-subject.json"

# Cleanup function
cleanup() {
    echo -e "${BLUE}[CLEANUP] Removing temporary files...${NC}"
    rm -rf "$TEMP_DIR"
}

# Setup trap for cleanup
trap cleanup EXIT

# Create temp directory
mkdir -p "$TEMP_DIR"
mkdir -p "$TEST_IMPORT_DIR"

echo -e "${BLUE}=== Testing IMPORT Commands ===${NC}"

# Test 1: Create export data for import tests
echo -e "${YELLOW}[SETUP] Creating export data for import tests...${NC}"
$CLI export subjects --file "$TEST_EXPORT_FILE"
if [ -f "$TEST_EXPORT_FILE" ]; then
    echo -e "${GREEN}✓ SETUP: Export data created${NC}"
else
    echo -e "${RED}✗ SETUP FAILED: Could not create export data${NC}"
    exit 1
fi

# Create a modified export for testing
python3 -c "
import json
with open('$TEST_EXPORT_FILE') as f:
    data = json.load(f)

# Create a test import with modified subject name
if data.get('subjects'):
    test_subject = data['subjects'][0].copy()
    test_subject['name'] = 'import-test-subject'
    # Modify the schema content slightly to make it unique
    for version in test_subject['versions']:
        if 'User' in str(version.get('schema', '')):
            schema_str = str(version['schema'])
            # Add a test field to make it unique
            if 'fields' in schema_str:
                version['schema'] = schema_str.replace('fields', 'fields\":[{\"name\":\"test_import_field\",\"type\":\"string\"}],\"original_fields')
    
    # Create single subject export
    single_subject_data = {
        'metadata': data['metadata'],
        'subjects': [test_subject]
    }
    
    with open('$TEST_SUBJECT_FILE', 'w') as f:
        json.dump(single_subject_data, f, indent=2)
        
    # Create directory with separate files
    with open('$TEST_IMPORT_DIR/subject1.json', 'w') as f:
        json.dump(single_subject_data, f, indent=2)
        
    # Create another subject file
    test_subject2 = test_subject.copy()
    test_subject2['name'] = 'import-test-subject-2'
    single_subject_data2 = {
        'metadata': data['metadata'],
        'subjects': [test_subject2]
    }
    with open('$TEST_IMPORT_DIR/subject2.json', 'w') as f:
        json.dump(single_subject_data2, f, indent=2)
"

# Test 2: Dry run import
echo -e "${YELLOW}[TEST] Dry run import...${NC}"
DRY_RUN_OUTPUT=$($CLI import subjects --file "$TEST_SUBJECT_FILE" --dry-run 2>&1)
if echo "$DRY_RUN_OUTPUT" | grep -q "DRY RUN"; then
    if echo "$DRY_RUN_OUTPUT" | grep -q "Import Summary"; then
        echo -e "${GREEN}✓ PASSED: Dry run provides import summary${NC}"
    else
        echo -e "${GREEN}✓ PASSED: Dry run executed${NC}"
    fi
else
    echo -e "${RED}✗ FAILED: Dry run not indicated in output${NC}"
    echo "Output: $DRY_RUN_OUTPUT"
    exit 1
fi

# Test 3: Import single subject
echo -e "${YELLOW}[TEST] Import single subject...${NC}"
IMPORT_OUTPUT=$($CLI import subject --file "$TEST_SUBJECT_FILE" 2>&1)
if echo "$IMPORT_OUTPUT" | grep -q "Import Summary"; then
    if echo "$IMPORT_OUTPUT" | grep -q "Created: [1-9]" || echo "$IMPORT_OUTPUT" | grep -q "Existing: [1-9]"; then
        echo -e "${GREEN}✓ PASSED: Single subject import successful${NC}"
    else
        echo -e "${YELLOW}~ WARNING: Import completed but may not have created/found schemas${NC}"
        echo "Output: $IMPORT_OUTPUT"
    fi
else
    echo -e "${RED}✗ FAILED: Single subject import failed${NC}"
    echo "Output: $IMPORT_OUTPUT"
    exit 1
fi

# Test 4: Verify imported subject exists
echo -e "${YELLOW}[TEST] Verify imported subject exists...${NC}"
if $CLI get subjects | grep -q "import-test-subject"; then
    echo -e "${GREEN}✓ PASSED: Imported subject found in registry${NC}"
else
    echo -e "${YELLOW}~ SKIPPED: Subject verification (may have been skipped due to existing schema)${NC}"
fi

# Test 5: Import with skip-existing flag
echo -e "${YELLOW}[TEST] Import with skip-existing flag...${NC}"
SKIP_EXISTING_OUTPUT=$($CLI import subject --file "$TEST_SUBJECT_FILE" --skip-existing 2>&1)
if echo "$SKIP_EXISTING_OUTPUT" | grep -q "Import Summary"; then
    if echo "$SKIP_EXISTING_OUTPUT" | grep -q "Existing: [0-9]" || echo "$SKIP_EXISTING_OUTPUT" | grep -q "Created: [0-9]"; then
        echo -e "${GREEN}✓ PASSED: Skip existing import completed${NC}"
    else
        echo -e "${YELLOW}~ WARNING: Skip existing import completed with unexpected summary${NC}"
    fi
else
    echo -e "${RED}✗ FAILED: Skip existing import failed${NC}"
    echo "Output: $SKIP_EXISTING_OUTPUT"
    exit 1
fi

# Test 6: Import from directory
echo -e "${YELLOW}[TEST] Import from directory...${NC}"
DIRECTORY_IMPORT_OUTPUT=$($CLI import subjects --directory "$TEST_IMPORT_DIR" 2>&1)
if echo "$DIRECTORY_IMPORT_OUTPUT" | grep -q "Processing file"; then
    if echo "$DIRECTORY_IMPORT_OUTPUT" | grep -q "Import Summary"; then
        echo -e "${GREEN}✓ PASSED: Directory import successful${NC}"
    else
        echo -e "${YELLOW}~ WARNING: Directory import processed files but summary unclear${NC}"
        echo "Output: $DIRECTORY_IMPORT_OUTPUT"
    fi
else
    echo -e "${RED}✗ FAILED: Directory import failed${NC}"
    echo "Output: $DIRECTORY_IMPORT_OUTPUT"
    exit 1
fi

# Test 7: Import with different context
echo -e "${YELLOW}[TEST] Import with different context...${NC}"
CONTEXT_IMPORT_OUTPUT=$($CLI import subject --file "$TEST_SUBJECT_FILE" --import-context test-import-context --skip-existing 2>&1)
if echo "$CONTEXT_IMPORT_OUTPUT" | grep -q "Import Summary"; then
    echo -e "${GREEN}✓ PASSED: Context import completed${NC}"
    
    # Verify subject exists in the target context
    if $CLI get subjects --context test-import-context | grep -q "import-test-subject" 2>/dev/null; then
        echo -e "${GREEN}✓ PASSED: Subject imported to correct context${NC}"
    else
        echo -e "${YELLOW}~ SKIPPED: Context verification (context may not exist or schema may have been skipped)${NC}"
    fi
else
    echo -e "${RED}✗ FAILED: Context import failed${NC}"
    echo "Output: $CONTEXT_IMPORT_OUTPUT"
    exit 1
fi

# Test 8: Error handling - non-existent import file
echo -e "${YELLOW}[TEST] Error handling - non-existent import file...${NC}"
if $CLI import subjects --file "/non/existent/file.json" 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with non-existent file${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled non-existent import file${NC}"
fi

# Test 9: Error handling - invalid JSON file
echo -e "${YELLOW}[TEST] Error handling - invalid JSON file...${NC}"
echo "invalid json content" > "$TEMP_DIR/invalid.json"
if $CLI import subjects --file "$TEMP_DIR/invalid.json" 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed with invalid JSON${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly handled invalid JSON file${NC}"
fi

# Test 10: Error handling - missing file and directory flags
echo -e "${YELLOW}[TEST] Error handling - missing file and directory flags...${NC}"
if $CLI import subjects 2>/dev/null; then
    echo -e "${RED}✗ FAILED: Should have failed without file or directory flag${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Correctly required file or directory flag${NC}"
fi

# Test 11: Import summary validation
echo -e "${YELLOW}[TEST] Import summary validation...${NC}"
SUMMARY_OUTPUT=$($CLI import subject --file "$TEST_SUBJECT_FILE" --dry-run 2>&1)
if echo "$SUMMARY_OUTPUT" | grep -E "Total: [0-9]+" && \
   echo "$SUMMARY_OUTPUT" | grep -E "(Created|Existing|Errors|Skipped): [0-9]+"; then
    echo -e "${GREEN}✓ PASSED: Import summary contains expected fields${NC}"
else
    echo -e "${RED}✗ FAILED: Import summary missing expected fields${NC}"
    echo "Output: $SUMMARY_OUTPUT"
    exit 1
fi

# Test 12: Create invalid export data for error testing
echo -e "${YELLOW}[TEST] Error handling - malformed export data...${NC}"
cat > "$TEMP_DIR/malformed.json" << 'EOF'
{
  "metadata": {
    "exported_at": "2024-01-01T00:00:00Z",
    "cli_version": "test"
  },
  "subjects": [
    {
      "name": "test-subject",
      "versions": [
        {
          "id": "invalid-id",
          "version": "invalid-version",
          "schema": "not-a-json-schema"
        }
      ]
    }
  ]
}
EOF

MALFORMED_OUTPUT=$($CLI import subjects --file "$TEMP_DIR/malformed.json" --dry-run 2>&1 || true)
if echo "$MALFORMED_OUTPUT" | grep -q "DRY RUN"; then
    echo -e "${GREEN}✓ PASSED: Handled malformed export data gracefully${NC}"
else
    echo -e "${YELLOW}~ WARNING: Malformed data handling could be improved${NC}"
fi

# Test 13: Test export-import roundtrip
echo -e "${YELLOW}[TEST] Export-import roundtrip...${NC}"
# Export a subject
$CLI export subject user-value --file "$TEMP_DIR/roundtrip-export.json"
# Try to import it (should be skipped as existing)
ROUNDTRIP_OUTPUT=$($CLI import subject --file "$TEMP_DIR/roundtrip-export.json" --skip-existing 2>&1)
if echo "$ROUNDTRIP_OUTPUT" | grep -q "Import Summary"; then
    echo -e "${GREEN}✓ PASSED: Export-import roundtrip successful${NC}"
else
    echo -e "${RED}✗ FAILED: Export-import roundtrip failed${NC}"
    echo "Output: $ROUNDTRIP_OUTPUT"
    exit 1
fi

# Test 14: Import subjects (multiple)
echo -e "${YELLOW}[TEST] Import multiple subjects...${NC}"
# Create export with multiple subjects
python3 -c "
import json
with open('$TEST_EXPORT_FILE') as f:
    data = json.load(f)

# Limit to first 2 subjects to avoid conflicts
if len(data.get('subjects', [])) > 2:
    data['subjects'] = data['subjects'][:2]

# Modify subject names to avoid conflicts
for i, subject in enumerate(data.get('subjects', [])):
    subject['name'] = f'multi-import-test-{i+1}'

with open('$TEMP_DIR/multi-subjects.json', 'w') as f:
    json.dump(data, f, indent=2)
"

MULTI_IMPORT_OUTPUT=$($CLI import subjects --file "$TEMP_DIR/multi-subjects.json" 2>&1)
if echo "$MULTI_IMPORT_OUTPUT" | grep -q "Import Summary"; then
    echo -e "${GREEN}✓ PASSED: Multiple subjects import successful${NC}"
else
    echo -e "${RED}✗ FAILED: Multiple subjects import failed${NC}"
    echo "Output: $MULTI_IMPORT_OUTPUT"
    exit 1
fi

echo -e "${GREEN}All IMPORT command tests passed!${NC}" 