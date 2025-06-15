#!/bin/bash

# Script to start the test environment for ksr-cli
# This starts Kafka, Schema Registry, and AKHQ using docker-compose

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting ksr-cli test environment...${NC}"

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

# Start the services
echo -e "${YELLOW}Starting Docker containers...${NC}"
cd "$SCRIPT_DIR"
docker-compose up -d

# Wait for services to be healthy
echo -e "${YELLOW}Waiting for services to be healthy...${NC}"

# Function to check service health
check_service_health() {
    local service=$1
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose ps | grep -E "^${service}.*healthy" > /dev/null; then
            echo -e "${GREEN}✓ ${service} is healthy${NC}"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}✗ ${service} failed to become healthy${NC}"
    return 1
}

# Check each service
check_service_health "kafka" || exit 1
check_service_health "schema-registry" || exit 1
check_service_health "akhq" || exit 1

echo -e "${GREEN}All services are healthy!${NC}"
echo ""
echo -e "${GREEN}Test environment is ready:${NC}"
echo -e "  • Kafka:          ${YELLOW}localhost:39092${NC}"
echo -e "  • Schema Registry: ${YELLOW}localhost:38081${NC}"
echo -e "  • AKHQ UI:        ${YELLOW}http://localhost:38080${NC}"
echo ""
echo -e "${GREEN}Configure ksr-cli:${NC}"
echo -e "  ${YELLOW}ksr-cli config set registry-url http://localhost:38081${NC}"
echo ""
echo -e "${GREEN}To view logs:${NC}"
echo -e "  ${YELLOW}docker-compose logs -f${NC}"
echo ""
echo -e "${GREEN}To stop the environment:${NC}"
echo -e "  ${YELLOW}./tests/stop-test-env.sh${NC}"
