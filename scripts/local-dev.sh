#!/bin/bash

# PickStream Local Development Script
# This script helps you run the application locally using Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== PickStream Local Development ===${NC}\n"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose is not installed. Please install docker-compose and try again.${NC}"
    exit 1
fi

# Parse command line arguments
case "$1" in
    start)
        echo -e "${YELLOW}Starting PickStream services...${NC}"
        docker-compose up --build -d
        echo -e "\n${GREEN}✓ Services started!${NC}"
        echo -e "\nAccess the application at:"
        echo -e "  Frontend: ${GREEN}http://localhost:8081${NC}"
        echo -e "  Backend:  ${GREEN}http://localhost:8080${NC}"
        echo -e "  Backend Health: ${GREEN}http://localhost:8080/actuator/health${NC}"
        echo -e "  Backend Metrics: ${GREEN}http://localhost:8080/actuator/prometheus${NC}"
        echo -e "\nView logs with: ${YELLOW}./scripts/local-dev.sh logs${NC}"
        ;;
    
    stop)
        echo -e "${YELLOW}Stopping PickStream services...${NC}"
        docker-compose down
        echo -e "${GREEN}✓ Services stopped${NC}"
        ;;
    
    restart)
        echo -e "${YELLOW}Restarting PickStream services...${NC}"
        docker-compose restart
        echo -e "${GREEN}✓ Services restarted${NC}"
        ;;
    
    logs)
        if [ -z "$2" ]; then
            docker-compose logs -f
        else
            docker-compose logs -f "$2"
        fi
        ;;
    
    status)
        echo -e "${YELLOW}Service Status:${NC}"
        docker-compose ps
        ;;
    
    clean)
        echo -e "${YELLOW}Cleaning up containers, images, and volumes...${NC}"
        docker-compose down -v --rmi all
        echo -e "${GREEN}✓ Cleanup complete${NC}"
        ;;
    
    rebuild)
        echo -e "${YELLOW}Rebuilding services from scratch...${NC}"
        docker-compose down -v
        docker-compose build --no-cache
        docker-compose up -d
        echo -e "${GREEN}✓ Services rebuilt and started${NC}"
        ;;
    
    test)
        echo -e "${YELLOW}Running backend tests...${NC}"
        cd services/backend
        ./mvnw test
        cd ../..
        echo -e "${GREEN}✓ Tests complete${NC}"
        ;;
    
    *)
        echo "Usage: $0 {start|stop|restart|logs|status|clean|rebuild|test}"
        echo ""
        echo "Commands:"
        echo "  start    - Start all services"
        echo "  stop     - Stop all services"
        echo "  restart  - Restart all services"
        echo "  logs     - View logs (add service name for specific service)"
        echo "  status   - Show service status"
        echo "  clean    - Remove containers, images, and volumes"
        echo "  rebuild  - Rebuild services from scratch"
        echo "  test     - Run backend tests"
        exit 1
        ;;
esac
