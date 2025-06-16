#!/bin/bash

# compare-contexts-quick.sh - Quick context comparison between registries
# Usage: ./compare-contexts-quick.sh <source-registry> <target-registry> [source-context] [target-context]

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <source-registry> <target-registry> [source-context] [target-context]"
    echo "Example: $0 http://dev-registry:8081 http://prod-registry:8081"
    echo "Example: $0 http://registry:8081 http://registry:8081 dev prod"
    exit 1
fi

SOURCE_REGISTRY="$1"
TARGET_REGISTRY="$2"
SOURCE_CONTEXT="${3:-.}"
TARGET_CONTEXT="${4:-.}"

echo -e "${BLUE}Schema Registry Context Comparison${NC}"
echo -e "${BLUE}==================================${NC}"
echo -e "Source: $SOURCE_REGISTRY (context: $SOURCE_CONTEXT)"
echo -e "Target: $TARGET_REGISTRY (context: $TARGET_CONTEXT)"
echo

# Test connections
echo -n "Testing source connection... "
if ksr-cli check --registry-url "$SOURCE_REGISTRY" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

echo -n "Testing target connection... "
if ksr-cli check --registry-url "$TARGET_REGISTRY" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

echo

# Get subjects
echo "Fetching subjects..."
SOURCE_SUBJECTS=$(ksr-cli subjects list --registry-url "$SOURCE_REGISTRY" --context "$SOURCE_CONTEXT" -o json | jq -r '.[]' | sort)
TARGET_SUBJECTS=$(ksr-cli subjects list --registry-url "$TARGET_REGISTRY" --context "$TARGET_CONTEXT" -o json | jq -r '.[]' | sort)

# Create temp files
SOURCE_TEMP=$(mktemp)
TARGET_TEMP=$(mktemp)
echo "$SOURCE_SUBJECTS" > "$SOURCE_TEMP"
echo "$TARGET_SUBJECTS" > "$TARGET_TEMP"

# Count subjects
SOURCE_COUNT=$(echo "$SOURCE_SUBJECTS" | grep -v '^$' | wc -l || echo 0)
TARGET_COUNT=$(echo "$TARGET_SUBJECTS" | grep -v '^$' | wc -l || echo 0)

echo -e "\nSubject Count:"
echo -e "  Source: ${YELLOW}$SOURCE_COUNT${NC}"
echo -e "  Target: ${YELLOW}$TARGET_COUNT${NC}"

# Find differences
ONLY_IN_SOURCE=$(comm -23 "$SOURCE_TEMP" "$TARGET_TEMP" | grep -v '^$' || true)
ONLY_IN_TARGET=$(comm -13 "$SOURCE_TEMP" "$TARGET_TEMP" | grep -v '^$' || true)
COMMON_SUBJECTS=$(comm -12 "$SOURCE_TEMP" "$TARGET_TEMP" | grep -v '^$' || true)

# Clean up
rm -f "$SOURCE_TEMP" "$TARGET_TEMP"

# Display subjects only in source
if [[ -n "$ONLY_IN_SOURCE" ]]; then
    COUNT=$(echo "$ONLY_IN_SOURCE" | wc -l)
    echo -e "\n${RED}Subjects only in source ($COUNT):${NC}"
    echo "$ONLY_IN_SOURCE" | sed 's/^/  - /'
fi

# Display subjects only in target
if [[ -n "$ONLY_IN_TARGET" ]]; then
    COUNT=$(echo "$ONLY_IN_TARGET" | wc -l)
    echo -e "\n${YELLOW}Subjects only in target ($COUNT):${NC}"
    echo "$ONLY_IN_TARGET" | sed 's/^/  - /'
fi

# Compare common subjects
if [[ -n "$COMMON_SUBJECTS" ]]; then
    echo -e "\n${BLUE}Comparing common subjects...${NC}"
    
    identical=0
    different=0
    
    while IFS= read -r subject; do
        if [[ -z "$subject" ]]; then continue; fi
        
        # Get latest schema from both
        source_schema=$(ksr-cli schema get "$subject" \
            --registry-url "$SOURCE_REGISTRY" \
            --context "$SOURCE_CONTEXT" \
            -o json 2>/dev/null | jq -r '.schema' | jq -S .)
            
        target_schema=$(ksr-cli schema get "$subject" \
            --registry-url "$TARGET_REGISTRY" \
            --context "$TARGET_CONTEXT" \
            -o json 2>/dev/null | jq -r '.schema' | jq -S .)
        
        if [[ "$source_schema" == "$target_schema" ]]; then
            echo -e "  ${GREEN}✓${NC} $subject"
            ((identical++))
        else
            echo -e "  ${YELLOW}✗${NC} $subject (schemas differ)"
            ((different++))
        fi
    done <<< "$COMMON_SUBJECTS"
    
    echo -e "\n${BLUE}Common subjects summary:${NC}"
    echo -e "  ${GREEN}Identical: $identical${NC}"
    echo -e "  ${YELLOW}Different: $different${NC}"
fi

# Final summary
echo -e "\n${BLUE}==================================${NC}"
echo -e "${BLUE}Overall Summary:${NC}"
echo -e "  Total unique subjects: $((SOURCE_COUNT > TARGET_COUNT ? SOURCE_COUNT : TARGET_COUNT))"
echo -e "  Missing in target: $(echo "$ONLY_IN_SOURCE" | grep -v '^$' | wc -l || echo 0)"
echo -e "  Missing in source: $(echo "$ONLY_IN_TARGET" | grep -v '^$' | wc -l || echo 0)"

# Exit with error if differences found
if [[ -n "$ONLY_IN_SOURCE" ]] || [[ -n "$ONLY_IN_TARGET" ]] || [[ $different -gt 0 ]]; then
    exit 1
else
    echo -e "\n${GREEN}✓ Contexts are identical${NC}"
    exit 0
fi
