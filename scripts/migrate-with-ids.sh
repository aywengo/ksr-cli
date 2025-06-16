#!/bin/bash

# migrate-with-ids.sh - Migrate schemas preserving IDs and versions
# This script migrates schemas between registries while preserving:
# - Schema IDs
# - Version numbers
# - Compatibility settings
# - Schema evolution history
#
# Usage: ./migrate-with-ids.sh [options]
#
# Options:
#   -s, --source-registry URL      Source registry URL (required)
#   -t, --target-registry URL      Target registry URL (required)
#   -sc, --source-context NAME     Source context (default: ".")
#   -tc, --target-context NAME     Target context (default: ".")
#   -sa, --source-auth AUTH        Source auth (user:pass or api-key)
#   -ta, --target-auth AUTH        Target auth (user:pass or api-key)
#   -sub, --subject SUBJECT        Specific subject to migrate (optional, default: all)
#   -d, --dry-run                  Show what would be migrated without making changes
#   -f, --force                    Force migration even if subject exists in target
#   -b, --backup-dir DIR           Directory to store backups (default: ./migration-backups)
#   -v, --verbose                  Enable verbose output
#   -h, --help                     Show this help message

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
SOURCE_REGISTRY=""
TARGET_REGISTRY=""
SOURCE_CONTEXT="."
TARGET_CONTEXT="."
SOURCE_AUTH=""
TARGET_AUTH=""
SPECIFIC_SUBJECT=""
DRY_RUN=false
FORCE=false
BACKUP_DIR="./migration-backups"
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
        -sub|--subject)
            SPECIFIC_SUBJECT="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -b|--backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            grep "^#" "$0" | grep -E "^# (migrate-with-ids|Usage|Options):" -A 25 | sed 's/^# //'
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
        echo -e "${CYAN}[VERBOSE]${NC} $1" >&2
    fi
}

# Function to test registry connection
test_connection() {
    local registry="$1"
    local auth_flags="$2"
    
    log_verbose "Testing connection to $registry"
    
    if eval ksr-cli check --registry-url "$registry" $auth_flags >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to get registry mode
get_registry_mode() {
    local registry="$1"
    local auth_flags="$2"
    local context="$3"
    
    eval ksr-cli mode get \
        --registry-url "$registry" \
        --context "$context" \
        $auth_flags \
        -o json 2>/dev/null | jq -r '.mode // "READWRITE"'
}

# Function to set registry mode
set_registry_mode() {
    local mode="$1"
    local registry="$2"
    local auth_flags="$3"
    local context="$4"
    
    log_verbose "Setting registry mode to $mode for $registry (context: $context)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${BLUE}[DRY RUN]${NC} Would set mode to $mode"
        return 0
    fi
    
    eval ksr-cli mode set "$mode" \
        --registry-url "$registry" \
        --context "$context" \
        $auth_flags
}

# Function to get all subjects or specific subject
get_subjects() {
    local registry="$1"
    local auth_flags="$2"
    local context="$3"
    local specific="$4"
    
    if [[ -n "$specific" ]]; then
        # Check if subject exists
        if eval ksr-cli schema get "$specific" \
            --registry-url "$registry" \
            --context "$context" \
            $auth_flags >/dev/null 2>&1; then
            echo "$specific"
        fi
    else
        eval ksr-cli subjects list \
            --registry-url "$registry" \
            --context "$context" \
            $auth_flags \
            -o json 2>/dev/null | jq -r '.[]' | sort
    fi
}

# Function to export subject with all metadata
export_subject_full() {
    local subject="$1"
    local registry="$2"
    local auth_flags="$3"
    local context="$4"
    local output_file="$5"
    
    log_verbose "Exporting subject $subject with full metadata"
    
    # Export using ksr-cli
    eval ksr-cli export subject "$subject" \
        --registry-url "$registry" \
        --context "$context" \
        $auth_flags \
        --all-versions \
        --include-config \
        -o json > "$output_file"
}

# Function to get schema by ID to verify preservation
get_schema_by_id() {
    local schema_id="$1"
    local registry="$2"
    local auth_flags="$3"
    
    # Direct API call to get schema by ID
    local auth_header=""
    if [[ -n "$SOURCE_AUTH" ]]; then
        if [[ "$SOURCE_AUTH" == *":"* ]]; then
            auth_header="-u $SOURCE_AUTH"
        else
            auth_header="-H 'Authorization: Bearer $SOURCE_AUTH'"
        fi
    fi
    
    curl -s $auth_header "$registry/schemas/ids/$schema_id" 2>/dev/null || echo "{}"
}

# Function to migrate a single subject preserving IDs and versions
migrate_subject_with_ids() {
    local subject="$1"
    local export_file="$2"
    
    echo -e "\n${BLUE}Migrating subject: $subject${NC}"
    
    # Parse export file
    local subject_data=$(jq -r '.' "$export_file")
    local versions=$(echo "$subject_data" | jq -r '.versions[]')
    local config=$(echo "$subject_data" | jq -r '.config // {}')
    local compatibility=$(echo "$config" | jq -r '.compatibilityLevel // "BACKWARD"')
    
    # Check if subject exists in target
    if eval ksr-cli schema get "$subject" \
        --registry-url "$TARGET_REGISTRY" \
        --context "$TARGET_CONTEXT" \
        $TARGET_AUTH_FLAGS >/dev/null 2>&1; then
        
        if [[ "$FORCE" != "true" ]]; then
            echo -e "  ${YELLOW}⚠ Subject already exists in target. Use --force to overwrite${NC}"
            return 1
        else
            echo -e "  ${YELLOW}⚠ Subject exists in target. Force mode enabled - will overwrite${NC}"
            
            if [[ "$DRY_RUN" != "true" ]]; then
                # Delete existing subject
                log_verbose "Deleting existing subject in target"
                eval ksr-cli subject delete "$subject" \
                    --registry-url "$TARGET_REGISTRY" \
                    --context "$TARGET_CONTEXT" \
                    $TARGET_AUTH_FLAGS
            fi
        fi
    fi
    
    # Set subject compatibility if different from default
    if [[ "$compatibility" != "BACKWARD" ]]; then
        echo -e "  Setting compatibility: ${YELLOW}$compatibility${NC}"
        
        if [[ "$DRY_RUN" != "true" ]]; then
            eval ksr-cli config set \
                --subject "$subject" \
                --context "$TARGET_CONTEXT" \
                --registry-url "$TARGET_REGISTRY" \
                $TARGET_AUTH_FLAGS \
                --compatibility "$compatibility"
        fi
    fi
    
    # Process each version in order
    echo "$subject_data" | jq -c '.versions | sort_by(.version)[]' | while read -r version_json; do
        local version=$(echo "$version_json" | jq -r '.version')
        local schema_id=$(echo "$version_json" | jq -r '.id')
        local schema=$(echo "$version_json" | jq -r '.schema')
        local schema_type=$(echo "$version_json" | jq -r '.schemaType // "AVRO"')
        local references=$(echo "$version_json" | jq -r '.references // []')
        
        echo -e "  ${CYAN}Version $version${NC} (ID: $schema_id, Type: $schema_type)"
        
        # Create temporary schema file
        local temp_schema_file=$(mktemp)
        echo "$schema" > "$temp_schema_file"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "    ${BLUE}[DRY RUN]${NC} Would register schema with ID $schema_id"
        else
            # Register schema
            log_verbose "Registering schema version $version with ID $schema_id"
            
            # In IMPORT mode, the schema should be registered with the same ID
            # We use the API directly to ensure ID preservation
            local auth_header=""
            if [[ -n "$TARGET_AUTH" ]]; then
                if [[ "$TARGET_AUTH" == *":"* ]]; then
                    auth_header="-u $TARGET_AUTH"
                else
                    auth_header="-H 'Authorization: Bearer $TARGET_AUTH'"
                fi
            fi
            
            # Prepare the request body
            local request_body=$(jq -n \
                --arg schema "$schema" \
                --arg schemaType "$schema_type" \
                --argjson id "$schema_id" \
                --argjson references "$references" \
                '{
                    schema: $schema,
                    schemaType: $schemaType,
                    id: $id,
                    references: $references
                }')
            
            # Register with specific ID in IMPORT mode
            local context_path=""
            if [[ "$TARGET_CONTEXT" != "." ]]; then
                context_path="/contexts/$TARGET_CONTEXT"
            fi
            
            local response=$(curl -s -X POST \
                $auth_header \
                -H "Content-Type: application/vnd.schemaregistry.v1+json" \
                -d "$request_body" \
                "$TARGET_REGISTRY$context_path/subjects/$subject/versions")
            
            local registered_id=$(echo "$response" | jq -r '.id // "error"')
            
            if [[ "$registered_id" == "$schema_id" ]]; then
                echo -e "    ${GREEN}✓ Successfully registered with ID $schema_id${NC}"
            elif [[ "$registered_id" == "error" ]]; then
                echo -e "    ${RED}✗ Failed to register: $response${NC}"
                rm -f "$temp_schema_file"
                return 1
            else
                echo -e "    ${YELLOW}⚠ Registered with different ID: $registered_id (expected: $schema_id)${NC}"
            fi
        fi
        
        rm -f "$temp_schema_file"
    done
    
    echo -e "  ${GREEN}✓ Subject migration complete${NC}"
    return 0
}

# Main execution
echo -e "${MAGENTA}Schema Migration with ID Preservation${NC}"
echo -e "${MAGENTA}====================================${NC}"
echo -e "Source: $SOURCE_REGISTRY (context: $SOURCE_CONTEXT)"
echo -e "Target: $TARGET_REGISTRY (context: $TARGET_CONTEXT)"

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${BLUE}Running in DRY RUN mode - no changes will be made${NC}"
fi

echo

# Test connections
echo -e "${BLUE}Testing connections...${NC}"

if ! test_connection "$SOURCE_REGISTRY" "$SOURCE_AUTH_FLAGS"; then
    echo -e "${RED}Error: Cannot connect to source registry${NC}"
    exit 1
fi
echo -e "  Source: ${GREEN}✓${NC}"

if ! test_connection "$TARGET_REGISTRY" "$TARGET_AUTH_FLAGS"; then
    echo -e "${RED}Error: Cannot connect to target registry${NC}"
    exit 1
fi
echo -e "  Target: ${GREEN}✓${NC}"

# Check and set target registry mode
echo -e "\n${BLUE}Checking registry modes...${NC}"

source_mode=$(get_registry_mode "$SOURCE_REGISTRY" "$SOURCE_AUTH_FLAGS" "$SOURCE_CONTEXT")
echo -e "  Source mode: ${YELLOW}$source_mode${NC}"

target_mode=$(get_registry_mode "$TARGET_REGISTRY" "$TARGET_AUTH_FLAGS" "$TARGET_CONTEXT")
echo -e "  Target mode: ${YELLOW}$target_mode${NC}"

if [[ "$target_mode" != "IMPORT" ]]; then
    echo -e "\n${YELLOW}Target registry is not in IMPORT mode${NC}"
    echo -e "Setting target registry to IMPORT mode to preserve schema IDs..."
    
    set_registry_mode "IMPORT" "$TARGET_REGISTRY" "$TARGET_AUTH_FLAGS" "$TARGET_CONTEXT"
    
    # Track that we changed the mode so we can restore it
    RESTORE_MODE="$target_mode"
else
    RESTORE_MODE=""
fi

# Create backup directory
if [[ "$DRY_RUN" != "true" ]]; then
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_PATH="$BACKUP_DIR/migration-$TIMESTAMP"
    mkdir -p "$BACKUP_PATH"
    echo -e "\n${BLUE}Backup directory: $BACKUP_PATH${NC}"
fi

# Get subjects to migrate
echo -e "\n${BLUE}Getting subjects to migrate...${NC}"
SUBJECTS=$(get_subjects "$SOURCE_REGISTRY" "$SOURCE_AUTH_FLAGS" "$SOURCE_CONTEXT" "$SPECIFIC_SUBJECT")

if [[ -z "$SUBJECTS" ]]; then
    if [[ -n "$SPECIFIC_SUBJECT" ]]; then
        echo -e "${RED}Error: Subject '$SPECIFIC_SUBJECT' not found in source registry${NC}"
    else
        echo -e "${RED}Error: No subjects found in source registry${NC}"
    fi
    exit 1
fi

SUBJECT_COUNT=$(echo "$SUBJECTS" | wc -l)
echo -e "Found ${YELLOW}$SUBJECT_COUNT${NC} subject(s) to migrate"

# Export and migrate each subject
SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_SUBJECTS=""

while IFS= read -r subject; do
    if [[ -z "$subject" ]]; then continue; fi
    
    # Export subject
    if [[ "$DRY_RUN" != "true" ]]; then
        export_file="$BACKUP_PATH/${subject//\//_}.json"
    else
        export_file=$(mktemp)
    fi
    
    log_verbose "Exporting $subject to $export_file"
    export_subject_full "$subject" "$SOURCE_REGISTRY" "$SOURCE_AUTH_FLAGS" "$SOURCE_CONTEXT" "$export_file"
    
    # Migrate subject
    if migrate_subject_with_ids "$subject" "$export_file"; then
        ((SUCCESS_COUNT++))
    else
        ((FAILED_COUNT++))
        FAILED_SUBJECTS+="$subject\n"
    fi
    
    # Clean up temp file if dry run
    if [[ "$DRY_RUN" == "true" ]]; then
        rm -f "$export_file"
    fi
    
done <<< "$SUBJECTS"

# Restore target registry mode if we changed it
if [[ -n "$RESTORE_MODE" ]] && [[ "$DRY_RUN" != "true" ]]; then
    echo -e "\n${BLUE}Restoring target registry mode to $RESTORE_MODE${NC}"
    set_registry_mode "$RESTORE_MODE" "$TARGET_REGISTRY" "$TARGET_AUTH_FLAGS" "$TARGET_CONTEXT"
fi

# Summary
echo -e "\n${MAGENTA}====================================${NC}"
echo -e "${MAGENTA}Migration Summary${NC}"
echo -e "${MAGENTA}====================================${NC}"
echo -e "Total subjects: $SUBJECT_COUNT"
echo -e "  ${GREEN}Successful: $SUCCESS_COUNT${NC}"
echo -e "  ${RED}Failed: $FAILED_COUNT${NC}"

if [[ $FAILED_COUNT -gt 0 ]]; then
    echo -e "\n${RED}Failed subjects:${NC}"
    echo -e "$FAILED_SUBJECTS"
fi

if [[ "$DRY_RUN" != "true" ]] && [[ $SUCCESS_COUNT -gt 0 ]]; then
    echo -e "\n${GREEN}Backup location: $BACKUP_PATH${NC}"
fi

# Exit with appropriate code
if [[ $FAILED_COUNT -gt 0 ]]; then
    exit 1
else
    exit 0
fi
