#!/bin/bash

# migrate-schemas-from-list.sh - Migrate schemas from a list file
# This script is a wrapper around migrate-with-ids.sh that reads a list of schemas
# from a text file and migrates them one by one.
#
# Usage: ./migrate-schemas-from-list.sh [options]
#
# Options:
#   --schemas FILE                 Text file containing list of schemas (one per line) (required)
#   -s, --source-registry URL      Source registry URL (required)
#   -t, --target-registry URL      Target registry URL (required)
#   -sc, --source-context NAME     Source context (default: ".")
#   -tc, --target-context NAME     Target context (default: ".")
#   -sa, --source-auth AUTH        Source auth (user:pass or api-key)
#   -ta, --target-auth AUTH        Target auth (user:pass or api-key)
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
SCHEMAS_FILE=""
SOURCE_REGISTRY=""
TARGET_REGISTRY=""
SOURCE_CONTEXT="."
TARGET_CONTEXT="."
SOURCE_AUTH=""
TARGET_AUTH=""
DRY_RUN=false
FORCE=false
BACKUP_DIR="./migration-backups"
VERBOSE=false

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATE_SCRIPT="$SCRIPT_DIR/migrate-with-ids.sh"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --schemas)
            SCHEMAS_FILE="$2"
            shift 2
            ;;
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
            grep "^#" "$0" | grep -E "^# (migrate-schemas-from-list|Usage|Options):" -A 20 | sed 's/^# //'
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
if [[ -z "$SCHEMAS_FILE" ]]; then
    echo -e "${RED}Error: --schemas file is required${NC}"
    echo "Use -h or --help for usage information"
    exit 1
fi

if [[ -z "$SOURCE_REGISTRY" || -z "$TARGET_REGISTRY" ]]; then
    echo -e "${RED}Error: Source and target registry URLs are required${NC}"
    echo "Use -h or --help for usage information"
    exit 1
fi

# Check if schemas file exists
if [[ ! -f "$SCHEMAS_FILE" ]]; then
    echo -e "${RED}Error: Schemas file '$SCHEMAS_FILE' not found${NC}"
    exit 1
fi

# Check if migrate-with-ids.sh exists
if [[ ! -f "$MIGRATE_SCRIPT" ]]; then
    echo -e "${RED}Error: migrate-with-ids.sh script not found at $MIGRATE_SCRIPT${NC}"
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

# Function to log verbose messages
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}[VERBOSE]${NC} $1" >&2
    fi
}

# Function to check if schema exists in source registry
schema_exists_in_source() {
    local subject="$1"
    
    log_verbose "Checking if schema '$subject' exists in source registry"
    
    if eval ksr-cli schema get "$subject" \
        --registry-url "$SOURCE_REGISTRY" \
        --context "$SOURCE_CONTEXT" \
        $SOURCE_AUTH_FLAGS >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to build migrate command arguments
build_migrate_args() {
    local args=""
    
    args+=" --source-registry '$SOURCE_REGISTRY'"
    args+=" --target-registry '$TARGET_REGISTRY'"
    args+=" --source-context '$SOURCE_CONTEXT'"
    args+=" --target-context '$TARGET_CONTEXT'"
    
    if [[ -n "$SOURCE_AUTH" ]]; then
        args+=" --source-auth '$SOURCE_AUTH'"
    fi
    
    if [[ -n "$TARGET_AUTH" ]]; then
        args+=" --target-auth '$TARGET_AUTH'"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        args+=" --dry-run"
    fi
    
    if [[ "$FORCE" == "true" ]]; then
        args+=" --force"
    fi
    
    if [[ -n "$BACKUP_DIR" ]]; then
        args+=" --backup-dir '$BACKUP_DIR'"
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        args+=" --verbose"
    fi
    
    echo "$args"
}

# Main execution
echo -e "${MAGENTA}Schema Migration from List${NC}"
echo -e "${MAGENTA}=========================${NC}"
echo -e "Schemas file: $SCHEMAS_FILE"
echo -e "Source: $SOURCE_REGISTRY (context: $SOURCE_CONTEXT)"
echo -e "Target: $TARGET_REGISTRY (context: $TARGET_CONTEXT)"

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${BLUE}Running in DRY RUN mode - no changes will be made${NC}"
fi

echo

# Read schemas from file and clean up (remove empty lines and comments)
SCHEMAS=$(grep -v '^#' "$SCHEMAS_FILE" | grep -v '^[[:space:]]*$' | sort -u)

if [[ -z "$SCHEMAS" ]]; then
    echo -e "${RED}Error: No valid schemas found in file '$SCHEMAS_FILE'${NC}"
    echo "Make sure the file contains schema names (one per line) and is not empty"
    exit 1
fi

TOTAL_COUNT=$(echo "$SCHEMAS" | wc -l)
echo -e "Found ${YELLOW}$TOTAL_COUNT${NC} schema(s) to process from file"

# Build common migrate script arguments
MIGRATE_ARGS=$(build_migrate_args)

# Process each schema
SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0
FAILED_SCHEMAS=""
SKIPPED_SCHEMAS=""

echo

while IFS= read -r subject; do
    if [[ -z "$subject" ]]; then continue; fi
    
    # Remove any leading/trailing whitespace
    subject=$(echo "$subject" | xargs)
    
    echo -e "${BLUE}Processing schema: $subject${NC}"
    
    # Check if schema exists in source
    if ! schema_exists_in_source "$subject"; then
        echo -e "  ${YELLOW}⚠ Warning: Schema '$subject' does not exist in source registry - skipping${NC}"
        ((SKIPPED_COUNT++))
        SKIPPED_SCHEMAS+="$subject\n"
        echo
        continue
    fi
    
    echo -e "  ${GREEN}✓ Schema exists in source registry${NC}"
    
    # Run migration for this specific schema
    log_verbose "Running migration for schema: $subject"
    
    if eval "$MIGRATE_SCRIPT" $MIGRATE_ARGS --subject "'$subject'"; then
        echo -e "  ${GREEN}✓ Migration successful${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "  ${RED}✗ Migration failed${NC}"
        ((FAILED_COUNT++))
        FAILED_SCHEMAS+="$subject\n"
    fi
    
    echo
    
done <<< "$SCHEMAS"

# Summary
echo -e "${MAGENTA}=========================${NC}"
echo -e "${MAGENTA}Migration Summary${NC}"
echo -e "${MAGENTA}=========================${NC}"
echo -e "Total schemas in file: $TOTAL_COUNT"
echo -e "  ${GREEN}Successful migrations: $SUCCESS_COUNT${NC}"
echo -e "  ${RED}Failed migrations: $FAILED_COUNT${NC}"
echo -e "  ${YELLOW}Skipped (not found): $SKIPPED_COUNT${NC}"

if [[ $SKIPPED_COUNT -gt 0 ]]; then
    echo -e "\n${YELLOW}Skipped schemas (not found in source):${NC}"
    echo -e "$SKIPPED_SCHEMAS"
fi

if [[ $FAILED_COUNT -gt 0 ]]; then
    echo -e "\n${RED}Failed schemas:${NC}"
    echo -e "$FAILED_SCHEMAS"
fi

# Exit with appropriate code
if [[ $FAILED_COUNT -gt 0 ]]; then
    exit 1
else
    exit 0
fi 