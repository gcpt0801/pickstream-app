#!/bin/bash
# Setup firewall rules for GKE LoadBalancer access

set -e

PROJECT_ID="${GCP_PROJECT_ID:-gcp-terraform-demo-474514}"
NETWORK="${GKE_NETWORK:-pickstream-cluster-network}"

echo "Setting up firewall rules for project: $PROJECT_ID"

# Check if firewall rule already exists
if gcloud compute firewall-rules describe allow-loadbalancer-http --project=$PROJECT_ID &>/dev/null; then
  echo "Firewall rule 'allow-loadbalancer-http' already exists"
else
  echo "Creating firewall rule to allow HTTP traffic to LoadBalancer..."
  gcloud compute firewall-rules create allow-loadbalancer-http \
    --project=$PROJECT_ID \
    --network=$NETWORK \
    --allow=tcp:80,tcp:443 \
    --source-ranges=0.0.0.0/0 \
    --description="Allow HTTP/HTTPS traffic to LoadBalancer services" \
    --priority=1000
  
  echo "✅ Firewall rule created successfully"
fi

echo "Current firewall rules:"
gcloud compute firewall-rules list --project=$PROJECT_ID --filter="name~allow-loadbalancer"
