#!/bin/bash

# compare-contexts.sh - Compare contexts between Schema Registries
# Usage: ./compare-contexts.sh [options]
#
# Options:
#   -s, --source-registry URL      Source registry URL (required)
#   -t, --target-registry URL      Target registry URL (required)
#   -sc, --source-context NAME     Source context (default: ".")
#   -tc, --target-context NAME     Target context (default: ".")
#   -sa, --source-auth AUTH        Source auth (user:pass or api-key)
#   -ta, --target-auth AUTH        Target auth (user:pass or api-key)
#   -o, --output FORMAT            Output format: text, json, html (default: text)
#   -f, --output-file FILE         Output file (default: stdout)
#   -d, --detailed                 Show detailed schema differences
#   -v, --verbose                  Enable verbose output
#   -h, --help                     Show this help message

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SOURCE_REGISTRY=""
TARGET_REGISTRY=""
SOURCE_CONTEXT="."
TARGET_CONTEXT="."
SOURCE_AUTH=""
TARGET_AUTH=""
OUTPUT_FORMAT="text"
OUTPUT_FILE=""
DETAILED=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--source-registry)
            SOURCE_REGISTRY="$2"
            shift 2
            ;;
        -t|--target-registry)
            TARGET_REGISTRY="$2"
            shift 2
            ;;
        -sc|--source-context)
            SOURCE_CONTEXT="$2"
            shift 2
            ;;
        -tc|--target-context)
            TARGET_CONTEXT="$2"
            shift 2
            ;;
        -sa|--source-auth)
            SOURCE_AUTH="$2"
            shift 2
            ;;
        -ta|--target-auth)
            TARGET_AUTH="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -f|--output-file)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -d|--detailed)
            DETAILED=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            grep "^#" "$0" | grep -E "^# (Usage|Options):" -A 20 | sed 's/^# //'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SOURCE_REGISTRY" || -z "$TARGET_REGISTRY" ]]; then
    echo -e "${RED}Error: Source and target registry URLs are required${NC}"
    echo "Use -h or --help for usage information"
    exit 1
fi

# Function to build authentication flags
build_auth_flags() {
    local auth="$1"
    local flags=""
    
    if [[ -n "$auth" ]]; then
        if [[ "$auth" == *":"* ]]; then
            IFS=':' read -r user pass <<< "$auth"
            flags="--user $user --pass $pass"
        else
            flags="--api-key $auth"
        fi
    fi
    
    echo "$flags"
}

# Build authentication flags
SOURCE_AUTH_FLAGS=$(build_auth_flags "$SOURCE_AUTH")
TARGET_AUTH_FLAGS=$(build_auth_flags "$TARGET_AUTH")

# Function to log verbose messages
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1" >&2
    fi
}

# Function to test registry connection
test_connection() {
    local registry="$1"
    local auth_flags="$2"
    local context="$3"
    
    log_verbose "Testing connection to $registry (context: $context)"
    
    if eval ksr-cli check --registry-url "$registry" $auth_flags >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to get subjects from registry
get_subjects() {
    local registry="$1"
    local auth_flags="$2"
    local context="$3"
    
    eval ksr-cli subjects list \
        --registry-url "$registry" \
        --context "$context" \
        $auth_flags \
        -o json 2>/dev/null | jq -r '.[]' | sort
}

# Function to get schema details
get_schema_details() {
    local subject="$1"
    local registry="$2"
    local auth_flags="$3"
    local context="$4"
    
    eval ksr-cli schema get "$subject" \
        --registry-url "$registry" \
        --context "$context" \
        $auth_flags \
        -o json 2>/dev/null
}

# Function to get schema versions
get_schema_versions() {
    local subject="$1"
    local registry="$2"
    local auth_flags="$3"
    local context="$4"
    
    eval ksr-cli schema versions "$subject" \
        --registry-url "$registry" \
        --context "$context" \
        $auth_flags \
        -o json 2>/dev/null | jq -r '.[]' | sort -n
}

# Function to get subject config
get_subject_config() {
    local subject="$1"
    local registry="$2"
    local auth_flags="$3"
    local context="$4"
    
    eval ksr-cli config get \
        --subject "$subject" \
        --registry-url "$registry" \
        --context "$context" \
        $auth_flags \
        -o json 2>/dev/null | jq -r '.compatibilityLevel // "BACKWARD"'
}

# Function to compare two schemas
compare_schemas() {
    local schema1="$1"
    local schema2="$2"
    
    # Normalize schemas for comparison
    normalized1=$(echo "$schema1" | jq -S .)
    normalized2=$(echo "$schema2" | jq -S .)
    
    if [[ "$normalized1" == "$normalized2" ]]; then
        return 0
    else
        return 1
    fi
}

# Initialize comparison results
declare -A comparison_results
total_subjects=0
identical_subjects=0
different_subjects=0
missing_in_target=0
missing_in_source=0

# Test connections
echo -e "${BLUE}Testing connections...${NC}"

if ! test_connection "$SOURCE_REGISTRY" "$SOURCE_AUTH_FLAGS" "$SOURCE_CONTEXT"; then
    echo -e "${RED}Error: Cannot connect to source registry${NC}"
    exit 1
fi

if ! test_connection "$TARGET_REGISTRY" "$TARGET_AUTH_FLAGS" "$TARGET_CONTEXT"; then
    echo -e "${RED}Error: Cannot connect to target registry${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Connections verified${NC}"

# Get subjects from both registries
echo -e "\n${BLUE}Fetching subjects...${NC}"

SOURCE_SUBJECTS=$(get_subjects "$SOURCE_REGISTRY" "$SOURCE_AUTH_FLAGS" "$SOURCE_CONTEXT")
TARGET_SUBJECTS=$(get_subjects "$TARGET_REGISTRY" "$TARGET_AUTH_FLAGS" "$TARGET_CONTEXT")

SOURCE_COUNT=$(echo "$SOURCE_SUBJECTS" | grep -v '^$' | wc -l || echo 0)
TARGET_COUNT=$(echo "$TARGET_SUBJECTS" | grep -v '^$' | wc -l || echo 0)

echo -e "Source registry: ${YELLOW}$SOURCE_COUNT${NC} subjects"
echo -e "Target registry: ${YELLOW}$TARGET_COUNT${NC} subjects"

# Create temporary files for comparison
SOURCE_TEMP=$(mktemp)
TARGET_TEMP=$(mktemp)
echo "$SOURCE_SUBJECTS" > "$SOURCE_TEMP"
echo "$TARGET_SUBJECTS" > "$TARGET_TEMP"

# Find differences
ONLY_IN_SOURCE=$(comm -23 "$SOURCE_TEMP" "$TARGET_TEMP" | grep -v '^$' || true)
ONLY_IN_TARGET=$(comm -13 "$SOURCE_TEMP" "$TARGET_TEMP" | grep -v '^$' || true)
COMMON_SUBJECTS=$(comm -12 "$SOURCE_TEMP" "$TARGET_TEMP" | grep -v '^$' || true)

# Clean up temp files
rm -f "$SOURCE_TEMP" "$TARGET_TEMP"

# Start comparison report
REPORT_CONTENT=""
REPORT_JSON='{"comparison": {"source": {"registry": "'$SOURCE_REGISTRY'", "context": "'$SOURCE_CONTEXT'"}, "target": {"registry": "'$TARGET_REGISTRY'", "context": "'$TARGET_CONTEXT'"}, "summary": {}, "subjects": {}}}'

case "$OUTPUT_FORMAT" in
    text)
        REPORT_CONTENT="Schema Registry Context Comparison Report\n"
        REPORT_CONTENT+="=========================================\n"
        REPORT_CONTENT+="Generated: $(date)\n\n"
        REPORT_CONTENT+="Source Registry: $SOURCE_REGISTRY (context: $SOURCE_CONTEXT)\n"
        REPORT_CONTENT+="Target Registry: $TARGET_REGISTRY (context: $TARGET_CONTEXT)\n\n"
        ;;
    html)
        REPORT_CONTENT='<!DOCTYPE html>
<html>
<head>
    <title>Schema Registry Context Comparison</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { margin: 20px 0; }
        .identical { color: green; }
        .different { color: orange; }
        .missing { color: red; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .status-identical { background-color: #d4edda; }
        .status-different { background-color: #fff3cd; }
        .status-missing { background-color: #f8d7da; }
        .details { font-family: monospace; font-size: 12px; background-color: #f5f5f5; padding: 10px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Schema Registry Context Comparison</h1>
        <p>Generated: '$(date)'</p>
        <p><strong>Source:</strong> '$SOURCE_REGISTRY' (context: '$SOURCE_CONTEXT')</p>
        <p><strong>Target:</strong> '$TARGET_REGISTRY' (context: '$TARGET_CONTEXT')</p>
    </div>'
        ;;
esac

# Process subjects only in source
if [[ -n "$ONLY_IN_SOURCE" ]]; then
    missing_in_target=$(echo "$ONLY_IN_SOURCE" | wc -l)
    
    case "$OUTPUT_FORMAT" in
        text)
            REPORT_CONTENT+="\n${RED}Subjects only in source ($missing_in_target):${NC}\n"
            while IFS= read -r subject; do
                REPORT_CONTENT+="  - $subject\n"
                comparison_results["$subject"]="missing_in_target"
            done <<< "$ONLY_IN_SOURCE"
            ;;
        json)
            while IFS= read -r subject; do
                REPORT_JSON=$(echo "$REPORT_JSON" | jq ".subjects[\"$subject\"] = {\"status\": \"missing_in_target\"}")
                comparison_results["$subject"]="missing_in_target"
            done <<< "$ONLY_IN_SOURCE"
            ;;
        html)
            if [[ $missing_in_target -gt 0 ]]; then
                REPORT_CONTENT+='<h2 class="missing">Subjects only in source ('$missing_in_target')</h2><ul>'
                while IFS= read -r subject; do
                    REPORT_CONTENT+="<li>$subject</li>"
                    comparison_results["$subject"]="missing_in_target"
                done <<< "$ONLY_IN_SOURCE"
                REPORT_CONTENT+='</ul>'
            fi
            ;;
    esac
fi

# Process subjects only in target
if [[ -n "$ONLY_IN_TARGET" ]]; then
    missing_in_source=$(echo "$ONLY_IN_TARGET" | wc -l)
    
    case "$OUTPUT_FORMAT" in
        text)
            REPORT_CONTENT+="\n${YELLOW}Subjects only in target ($missing_in_source):${NC}\n"
            while IFS= read -r subject; do
                REPORT_CONTENT+="  - $subject\n"
                comparison_results["$subject"]="missing_in_source"
            done <<< "$ONLY_IN_TARGET"
            ;;
        json)
            while IFS= read -r subject; do
                REPORT_JSON=$(echo "$REPORT_JSON" | jq ".subjects[\"$subject\"] = {\"status\": \"missing_in_source\"}")
                comparison_results["$subject"]="missing_in_source"
            done <<< "$ONLY_IN_TARGET"
            ;;
        html)
            if [[ $missing_in_source -gt 0 ]]; then
                REPORT_CONTENT+='<h2 class="missing">Subjects only in target ('$missing_in_source')</h2><ul>'
                while IFS= read -r subject; do
                    REPORT_CONTENT+="<li>$subject</li>"
                    comparison_results["$subject"]="missing_in_source"
                done <<< "$ONLY_IN_TARGET"
                REPORT_CONTENT+='</ul>'
            fi
            ;;
    esac
fi

# Compare common subjects
if [[ -n "$COMMON_SUBJECTS" ]]; then
    echo -e "\n${BLUE}Comparing common subjects...${NC}"
    
    case "$OUTPUT_FORMAT" in
        text)
            REPORT_CONTENT+="\n${BLUE}Common subjects comparison:${NC}\n"
            ;;
        html)
            REPORT_CONTENT+='<h2>Common Subjects Comparison</h2>
            <table>
                <tr>
                    <th>Subject</th>
                    <th>Source Version</th>
                    <th>Target Version</th>
                    <th>Compatibility</th>
                    <th>Status</th>
                    <th>Details</th>
                </tr>'
            ;;
    esac
    
    common_count=0
    while IFS= read -r subject; do
        if [[ -z "$subject" ]]; then continue; fi
        
        ((common_count++))
        log_verbose "Comparing subject: $subject"
        
        # Get schema details from both registries
        source_schema_json=$(get_schema_details "$subject" "$SOURCE_REGISTRY" "$SOURCE_AUTH_FLAGS" "$SOURCE_CONTEXT")
        target_schema_json=$(get_schema_details "$subject" "$TARGET_REGISTRY" "$TARGET_AUTH_FLAGS" "$TARGET_CONTEXT")
        
        # Extract schema content
        source_schema=$(echo "$source_schema_json" | jq -r '.schema' 2>/dev/null || echo "{}")
        target_schema=$(echo "$target_schema_json" | jq -r '.schema' 2>/dev/null || echo "{}")
        
        # Extract versions
        source_version=$(echo "$source_schema_json" | jq -r '.version // "unknown"' 2>/dev/null || echo "unknown")
        target_version=$(echo "$target_schema_json" | jq -r '.version // "unknown"' 2>/dev/null || echo "unknown")
        
        # Get all versions if detailed comparison requested
        if [[ "$DETAILED" == "true" ]]; then
            source_versions=$(get_schema_versions "$subject" "$SOURCE_REGISTRY" "$SOURCE_AUTH_FLAGS" "$SOURCE_CONTEXT")
            target_versions=$(get_schema_versions "$subject" "$TARGET_REGISTRY" "$TARGET_AUTH_FLAGS" "$TARGET_CONTEXT")
            source_version_count=$(echo "$source_versions" | grep -v '^$' | wc -l || echo 0)
            target_version_count=$(echo "$target_versions" | grep -v '^$' | wc -l || echo 0)
        else
            source_version_count=0
            target_version_count=0
        fi
        
        # Get compatibility settings
        source_compat=$(get_subject_config "$subject" "$SOURCE_REGISTRY" "$SOURCE_AUTH_FLAGS" "$SOURCE_CONTEXT")
        target_compat=$(get_subject_config "$subject" "$TARGET_REGISTRY" "$TARGET_AUTH_FLAGS" "$TARGET_CONTEXT")
        
        # Compare schemas
        if compare_schemas "$source_schema" "$target_schema"; then
            status="identical"
            ((identical_subjects++))
            status_symbol="${GREEN}✓${NC}"
        else
            status="different"
            ((different_subjects++))
            status_symbol="${YELLOW}✗${NC}"
        fi
        
        comparison_results["$subject"]="$status"
        
        # Generate output based on format
        case "$OUTPUT_FORMAT" in
            text)
                REPORT_CONTENT+="  $subject: $status_symbol\n"
                REPORT_CONTENT+="    Source version: $source_version"
                if [[ "$DETAILED" == "true" ]]; then
                    REPORT_CONTENT+=" (total versions: $source_version_count)"
                fi
                REPORT_CONTENT+="\n"
                REPORT_CONTENT+="    Target version: $target_version"
                if [[ "$DETAILED" == "true" ]]; then
                    REPORT_CONTENT+=" (total versions: $target_version_count)"
                fi
                REPORT_CONTENT+="\n"
                
                if [[ "$source_compat" != "$target_compat" ]]; then
                    REPORT_CONTENT+="    ${YELLOW}Compatibility differs: $source_compat → $target_compat${NC}\n"
                fi
                
                if [[ "$DETAILED" == "true" && "$status" == "different" ]]; then
                    REPORT_CONTENT+="    ${YELLOW}Schema differences detected${NC}\n"
                fi
                REPORT_CONTENT+="\n"
                ;;
                
            json)
                subject_info="{
                    \"status\": \"$status\",
                    \"source_version\": \"$source_version\",
                    \"target_version\": \"$target_version\",
                    \"source_compatibility\": \"$source_compat\",
                    \"target_compatibility\": \"$target_compat\""
                
                if [[ "$DETAILED" == "true" ]]; then
                    subject_info+=",
                    \"source_version_count\": $source_version_count,
                    \"target_version_count\": $target_version_count"
                fi
                
                subject_info+="}"
                
                REPORT_JSON=$(echo "$REPORT_JSON" | jq ".subjects[\"$subject\"] = $subject_info")
                ;;
                
            html)
                compat_cell="$source_compat → $target_compat"
                if [[ "$source_compat" == "$target_compat" ]]; then
                    compat_cell="$source_compat"
                fi
                
                details=""
                if [[ "$DETAILED" == "true" ]]; then
                    details="Source versions: $source_version_count<br>Target versions: $target_version_count"
                fi
                
                REPORT_CONTENT+="<tr class=\"status-$status\">
                    <td>$subject</td>
                    <td>$source_version</td>
                    <td>$target_version</td>
                    <td>$compat_cell</td>
                    <td class=\"$status\">$status</td>
                    <td>$details</td>
                </tr>"
                ;;
        esac
        
    done <<< "$COMMON_SUBJECTS"
    
    if [[ "$OUTPUT_FORMAT" == "html" ]]; then
        REPORT_CONTENT+='</table>'
    fi
fi

# Calculate totals
total_subjects=$((SOURCE_COUNT > TARGET_COUNT ? SOURCE_COUNT : TARGET_COUNT))

# Add summary
case "$OUTPUT_FORMAT" in
    text)
        REPORT_CONTENT+="\n${BLUE}Summary:${NC}\n"
        REPORT_CONTENT+="Total subjects compared: $total_subjects\n"
        REPORT_CONTENT+="  ${GREEN}Identical: $identical_subjects${NC}\n"
        REPORT_CONTENT+="  ${YELLOW}Different: $different_subjects${NC}\n"
        REPORT_CONTENT+="  ${RED}Missing in target: $missing_in_target${NC}\n"
        REPORT_CONTENT+="  ${YELLOW}Missing in source: $missing_in_source${NC}\n"
        ;;
        
    json)
        REPORT_JSON=$(echo "$REPORT_JSON" | jq ".summary = {
            \"total_subjects\": $total_subjects,
            \"identical\": $identical_subjects,
            \"different\": $different_subjects,
            \"missing_in_target\": $missing_in_target,
            \"missing_in_source\": $missing_in_source,
            \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }")
        ;;
        
    html)
        REPORT_CONTENT+='<div class="summary">
            <h2>Summary</h2>
            <p>Total subjects compared: <strong>'$total_subjects'</strong></p>
            <ul>
                <li class="identical">Identical: '$identical_subjects'</li>
                <li class="different">Different: '$different_subjects'</li>
                <li class="missing">Missing in target: '$missing_in_target'</li>
                <li class="missing">Missing in source: '$missing_in_source'</li>
            </ul>
        </div>
        </body>
        </html>'
        ;;
esac

# Output report
if [[ -n "$OUTPUT_FILE" ]]; then
    case "$OUTPUT_FORMAT" in
        text)
            echo -e "$REPORT_CONTENT" > "$OUTPUT_FILE"
            ;;
        json)
            echo "$REPORT_JSON" | jq . > "$OUTPUT_FILE"
            ;;
        html)
            echo "$REPORT_CONTENT" > "$OUTPUT_FILE"
            ;;
    esac
    echo -e "\n${GREEN}Report saved to: $OUTPUT_FILE${NC}"
else
    case "$OUTPUT_FORMAT" in
        text)
            echo -e "$REPORT_CONTENT"
            ;;
        json)
            echo "$REPORT_JSON" | jq .
            ;;
        html)
            echo "$REPORT_CONTENT"
            ;;
    esac
fi

# Exit with appropriate code
if [[ $different_subjects -gt 0 || $missing_in_target -gt 0 || $missing_in_source -gt 0 ]]; then
    exit 1
else
    exit 0
fi
