#!/bin/bash

# Script to stop the test environment for ksr-cli
# This stops and optionally removes Kafka, Schema Registry, and AKHQ containers

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse command line arguments
REMOVE_VOLUMES=false
REMOVE_IMAGES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        -i|--images)
            REMOVE_IMAGES=true
            shift
            ;;
        -a|--all)
            REMOVE_VOLUMES=true
            REMOVE_IMAGES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Stop the ksr-cli test environment"
            echo ""
            echo "Options:"
            echo "  -v, --volumes    Remove volumes (deletes all data)"
            echo "  -i, --images     Remove downloaded images"
            echo "  -a, --all        Remove everything (volumes and images)"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${YELLOW}Stopping ksr-cli test environment...${NC}"

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose is not installed or not in PATH${NC}"
    exit 1
fi

# Check if docker-compose.yml exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}Error: docker-compose.yml not found at $COMPOSE_FILE${NC}"
    exit 1
fi

cd "$PROJECT_ROOT"

# Check if any containers are running
if ! docker-compose ps --quiet 2>/dev/null | grep -q .; then
    echo -e "${YELLOW}No containers are running${NC}"
else
    # Stop the services
    echo -e "${YELLOW}Stopping containers...${NC}"
    docker-compose stop
    
    # Remove containers
    echo -e "${YELLOW}Removing containers...${NC}"
    docker-compose rm -f
fi

# Remove volumes if requested
if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "${YELLOW}Removing volumes...${NC}"
    docker-compose down -v
    echo -e "${GREEN}✓ Volumes removed${NC}"
fi

# Remove images if requested
if [ "$REMOVE_IMAGES" = true ]; then
    echo -e "${YELLOW}Removing images...${NC}"
    docker-compose down --rmi all
    echo -e "${GREEN}✓ Images removed${NC}"
fi

echo -e "${GREEN}Test environment stopped successfully!${NC}"

# Show what was cleaned up
echo ""
echo -e "${GREEN}Cleanup summary:${NC}"
echo -e "  • Containers: ${GREEN}Removed${NC}"
if [ "$REMOVE_VOLUMES" = true ]; then
    echo -e "  • Volumes:    ${GREEN}Removed${NC} (all data deleted)"
else
    echo -e "  • Volumes:    ${YELLOW}Preserved${NC} (data retained)"
fi
if [ "$REMOVE_IMAGES" = true ]; then
    echo -e "  • Images:     ${GREEN}Removed${NC}"
else
    echo -e "  • Images:     ${YELLOW}Preserved${NC}"
fi

echo ""
echo -e "${GREEN}To start the environment again:${NC}"
echo -e "  ${YELLOW}./tests/start-test-env.sh${NC}"
