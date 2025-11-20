#!/bin/bash
# Fix Helm lock issue - Run this in GCP Cloud Shell

set -e

echo "Checking for stuck Helm releases..."

# Check current Helm status
helm list -n pickstream

echo ""
echo "Checking for pending Helm operations..."
kubectl get secrets -n pickstream -l owner=helm -l status=pending-install -o name
kubectl get secrets -n pickstream -l owner=helm -l status=pending-upgrade -o name

echo ""
echo "Rolling back to last successful release..."
helm rollback pickstream -n pickstream || echo "No previous release to rollback to"

echo ""
echo "Current Helm status:"
helm status pickstream -n pickstream

echo ""
echo "You can now retry the deployment manually with:"
echo "helm upgrade --install pickstream ./helm/pickstream \\"
echo "  --namespace pickstream \\"
echo "  --values ./helm/pickstream/values.yaml \\"
echo "  --values ./helm/pickstream/values-dev.yaml \\"
echo "  --wait --timeout 5m"
