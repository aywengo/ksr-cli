#!/bin/bash

# Script to check the status of the test environment

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}ksr-cli Test Environment Status${NC}"
echo -e "${BLUE}===============================${NC}"
echo ""

cd "$PROJECT_ROOT"

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose is not installed${NC}"
    exit 1
fi

# Check container status
echo -e "${YELLOW}Container Status:${NC}"
docker-compose ps

echo ""
echo -e "${YELLOW}Service Health:${NC}"

# Function to check service endpoint
check_endpoint() {
    local service=$1
    local url=$2
    local description=$3
    
    if curl -sf "$url" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $service ($description): ${GREEN}Running${NC} at $url"
    else
        echo -e "  ${RED}✗${NC} $service ($description): ${RED}Not accessible${NC} at $url"
    fi
}

# Check each service endpoint
check_endpoint "Kafka" "localhost:39092" "Broker"
check_endpoint "Schema Registry" "http://localhost:38081/subjects" "API"
check_endpoint "AKHQ" "http://localhost:38080/health" "Web UI"

echo ""
echo -e "${YELLOW}Quick Actions:${NC}"
echo -e "  • View logs:        ${BLUE}docker-compose logs -f [service]${NC}"
echo -e "  • Access AKHQ:      ${BLUE}open http://localhost:38080${NC}"
echo -e "  • Test connection:  ${BLUE}ksr-cli get subjects${NC}"
echo -e "  • Stop environment: ${BLUE}./tests/stop-test-env.sh${NC}"
