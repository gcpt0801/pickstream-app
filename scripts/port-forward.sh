#!/bin/bash

# Port Forward Script for GKE Services
# This script helps you access services running in GKE locally

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
NAMESPACE="${NAMESPACE:-pickstream}"
CLUSTER="${GKE_CLUSTER:-pickstream-dev}"
REGION="${GCP_REGION:-us-central1}"
PROJECT_ID="${GCP_PROJECT_ID:-your-gcp-project-id}"

echo -e "${GREEN}=== PickStream Port Forward ===${NC}\n"

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${YELLOW}Kubectl not configured. Configuring now...${NC}"
    gcloud container clusters get-credentials ${CLUSTER} \
        --region=${REGION} \
        --project=${PROJECT_ID}
fi

# Parse command
SERVICE="${1:-backend}"
LOCAL_PORT="${2:-8080}"

case "$SERVICE" in
    backend)
        REMOTE_PORT=8080
        SERVICE_NAME="pickstream-backend"
        echo -e "${YELLOW}Port forwarding backend service...${NC}"
        echo -e "Access at: ${GREEN}http://localhost:${LOCAL_PORT}${NC}"
        echo -e "Health: ${GREEN}http://localhost:${LOCAL_PORT}/actuator/health${NC}"
        echo -e "Metrics: ${GREEN}http://localhost:${LOCAL_PORT}/actuator/prometheus${NC}"
        echo -e "API: ${GREEN}http://localhost:${LOCAL_PORT}/api/random-name${NC}"
        ;;
    
    frontend)
        REMOTE_PORT=80
        SERVICE_NAME="pickstream-frontend"
        echo -e "${YELLOW}Port forwarding frontend service...${NC}"
        echo -e "Access at: ${GREEN}http://localhost:${LOCAL_PORT}${NC}"
        ;;
    
    *)
        echo -e "${RED}Unknown service: $SERVICE${NC}"
        echo "Usage: $0 {backend|frontend} [local-port]"
        exit 1
        ;;
esac

echo -e "\n${YELLOW}Press Ctrl+C to stop port forwarding${NC}\n"

kubectl port-forward -n ${NAMESPACE} svc/${SERVICE_NAME} ${LOCAL_PORT}:${REMOTE_PORT}
