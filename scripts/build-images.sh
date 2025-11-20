#!/bin/bash

# Build and Tag Docker Images Script
# This script builds both backend and frontend images and tags them appropriately

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-your-gcp-project-id}"
REGION="${GCP_REGION:-us-central1}"
REGISTRY="${REGION}-docker.pkg.dev"
REPOSITORY="pickstream"

# Parse arguments
VERSION="${1:-dev}"
BUILD_BACKEND="${BUILD_BACKEND:-true}"
BUILD_FRONTEND="${BUILD_FRONTEND:-true}"

echo -e "${GREEN}=== PickStream Image Builder ===${NC}\n"
echo "Version: $VERSION"
echo "Project: $PROJECT_ID"
echo "Registry: $REGISTRY/$PROJECT_ID/$REPOSITORY"
echo ""

# Build backend
if [ "$BUILD_BACKEND" = "true" ]; then
    echo -e "${YELLOW}Building backend image...${NC}"
    docker build \
        -t pickstream-backend:${VERSION} \
        -t pickstream-backend:latest \
        -t ${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/pickstream-backend:${VERSION} \
        -t ${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/pickstream-backend:latest \
        ./services/backend
    echo -e "${GREEN}✓ Backend image built${NC}\n"
fi

# Build frontend
if [ "$BUILD_FRONTEND" = "true" ]; then
    echo -e "${YELLOW}Building frontend image...${NC}"
    docker build \
        -t pickstream-frontend:${VERSION} \
        -t pickstream-frontend:latest \
        -t ${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/pickstream-frontend:${VERSION} \
        -t ${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/pickstream-frontend:latest \
        ./services/frontend
    echo -e "${GREEN}✓ Frontend image built${NC}\n"
fi

echo -e "${GREEN}=== Build Summary ===${NC}"
docker images | grep pickstream

echo -e "\n${YELLOW}To push images to Artifact Registry:${NC}"
echo "  gcloud auth configure-docker ${REGION}-docker.pkg.dev"
echo "  docker push ${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/pickstream-backend:${VERSION}"
echo "  docker push ${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/pickstream-frontend:${VERSION}"
