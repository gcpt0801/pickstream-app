# Deployment Guide

This guide provides step-by-step instructions for deploying PickStream to GKE.

## Prerequisites

### Required Tools

- `gcloud` CLI (Google Cloud SDK)
- `kubectl` (Kubernetes CLI)
- `helm` 3.13 or later
- Access to a GKE cluster

### Required Access

- GCP project with GKE API enabled
- IAM permissions:
  - `container.clusters.get`
  - `container.clusters.update`
  - `container.pods.list`
  - `container.services.list`

## Setup Steps

### 1. Configure gcloud

```bash
# Authenticate
gcloud auth login

# Set project
gcloud config set project your-gcp-project-id

# Set region
gcloud config set compute/region us-central1
```

### 2. Create Artifact Registry Repository

```bash
# Create repository for Docker images
gcloud artifacts repositories create pickstream \
  --repository-format=docker \
  --location=us-central1 \
  --description="PickStream container images"

# Configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### 3. Build and Push Images

```bash
# Set variables
export GCP_PROJECT_ID="your-gcp-project-id"
export VERSION="1.0.0"

# Build images
./scripts/build-images.sh ${VERSION}

# Push to Artifact Registry
docker push us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/pickstream/pickstream-backend:${VERSION}
docker push us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/pickstream/pickstream-frontend:${VERSION}
```

### 4. Configure kubectl

```bash
# Get cluster credentials
gcloud container clusters get-credentials pickstream-cluster \
  --zone=us-central1-a \
  --project=${GCP_PROJECT_ID}

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### 5. Setup Workload Identity (Optional but Recommended)

```bash
# Create GCP service account
gcloud iam service-accounts create pickstream-sa \
  --display-name="PickStream Service Account"

# Create Kubernetes service account
kubectl create namespace pickstream
kubectl create serviceaccount pickstream -n pickstream

# Bind service accounts
gcloud iam service-accounts add-iam-policy-binding \
  pickstream-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${GCP_PROJECT_ID}.svc.id.goog[pickstream/pickstream]"

# Annotate K8s service account
kubectl annotate serviceaccount pickstream \
  -n pickstream \
  iam.gke.io/gcp-service-account=pickstream-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com
```

## Deployment

### Development Environment

```bash
# Deploy to dev
helm upgrade --install pickstream ./helm/pickstream \
  --namespace pickstream \
  --create-namespace \
  --values ./helm/pickstream/values.yaml \
  --values ./helm/pickstream/values-dev.yaml \
  --set global.projectId=${GCP_PROJECT_ID} \
  --set backend.image.tag=${VERSION} \
  --set frontend.image.tag=${VERSION} \
  --wait \
  --timeout 5m

# Verify deployment
kubectl get all -n pickstream
```

### Staging Environment

```bash
# Deploy to staging
helm upgrade --install pickstream ./helm/pickstream \
  --namespace pickstream \
  --create-namespace \
  --values ./helm/pickstream/values.yaml \
  --values ./helm/pickstream/values-staging.yaml \
  --set global.projectId=${GCP_PROJECT_ID} \
  --set backend.image.tag=${VERSION} \
  --set frontend.image.tag=${VERSION} \
  --wait \
  --timeout 5m
```

### Production Environment

```bash
# Deploy to production (use specific version, never 'latest')
helm upgrade --install pickstream ./helm/pickstream \
  --namespace pickstream \
  --create-namespace \
  --values ./helm/pickstream/values.yaml \
  --values ./helm/pickstream/values-prod.yaml \
  --set global.projectId=${GCP_PROJECT_ID} \
  --set backend.image.tag=1.0.0 \
  --set frontend.image.tag=1.0.0 \
  --wait \
  --timeout 10m

# Monitor deployment
kubectl rollout status deployment/pickstream-backend -n pickstream
kubectl rollout status deployment/pickstream-frontend -n pickstream
```

## Post-Deployment

### Verify Deployment

```bash
# Check pod status
kubectl get pods -n pickstream

# Check services
kubectl get svc -n pickstream

# Check ingress
kubectl get ingress -n pickstream

# Check HPA
kubectl get hpa -n pickstream
```

### Access Application

**Via Port Forward (Development)**:
```bash
# Backend
kubectl port-forward -n pickstream svc/pickstream-backend 8080:8080

# Frontend
kubectl port-forward -n pickstream svc/pickstream-frontend 8081:80
```

**Via Ingress (Production)**:
```bash
# Get ingress IP
kubectl get ingress pickstream -n pickstream

# Access via domain
curl https://pickstream.example.com
```

### Test Endpoints

```bash
# Health check
curl http://localhost:8080/api/health

# Get random name
curl http://localhost:8080/api/random-name

# View metrics
curl http://localhost:8080/actuator/prometheus
```

## GitHub Actions Setup

### Configure Secrets

In your GitHub repository, go to Settings > Secrets and variables > Actions, and add:

1. **GCP_PROJECT_ID**: Your Google Cloud project ID
   ```
   your-gcp-project-id
   ```

2. **WIF_PROVIDER**: Workload Identity Federation provider
   ```
   projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID
   ```

3. **WIF_SERVICE_ACCOUNT**: Service account email
   ```
   github-actions@your-gcp-project-id.iam.gserviceaccount.com
   ```

### Setup Workload Identity Federation

```bash
# Create workload identity pool
gcloud iam workload-identity-pools create github-pool \
  --location=global \
  --display-name="GitHub Actions Pool"

# Create provider
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location=global \
  --workload-identity-pool=github-pool \
  --issuer-uri=https://token.actions.githubusercontent.com \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository_owner=='yourusername'"

# Grant permissions
gcloud iam service-accounts add-iam-policy-binding \
  github-actions@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/container.developer \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/yourusername/pickstream-app"
```

### Trigger Deployments

**Development** (Automatic):
- Push to `main` branch triggers automatic deployment

**Staging** (Manual):
```bash
# Go to Actions tab in GitHub
# Select "Deploy to Staging"
# Click "Run workflow"
# Enter image tag (e.g., "1.0.0")
```

**Production** (Manual with Confirmation):
```bash
# Go to Actions tab in GitHub
# Select "Deploy to Production"
# Click "Run workflow"
# Enter image tag (e.g., "1.0.0")
# Enter confirmation: "DEPLOY_TO_PRODUCTION"
```

## Rollback

### Helm Rollback

```bash
# List releases
helm list -n pickstream

# View history
helm history pickstream -n pickstream

# Rollback to previous version
helm rollback pickstream -n pickstream

# Rollback to specific revision
helm rollback pickstream 3 -n pickstream
```

### Kubernetes Rollback

```bash
# Rollback deployment
kubectl rollout undo deployment/pickstream-backend -n pickstream
kubectl rollout undo deployment/pickstream-frontend -n pickstream

# Rollback to specific revision
kubectl rollout undo deployment/pickstream-backend --to-revision=2 -n pickstream
```

## Scaling

### Manual Scaling

```bash
# Scale backend
kubectl scale deployment pickstream-backend -n pickstream --replicas=5

# Scale frontend
kubectl scale deployment pickstream-frontend -n pickstream --replicas=3
```

### Update HPA

```bash
# Edit HPA
kubectl edit hpa pickstream-backend -n pickstream

# Or via Helm values
helm upgrade pickstream ./helm/pickstream \
  --namespace pickstream \
  --reuse-values \
  --set backend.autoscaling.maxReplicas=20
```

## Monitoring

### View Logs

```bash
# Backend logs
kubectl logs -f -n pickstream -l app.kubernetes.io/component=backend

# Frontend logs
kubectl logs -f -n pickstream -l app.kubernetes.io/component=frontend

# Specific pod
kubectl logs -f -n pickstream pickstream-backend-xxxx
```

### Resource Usage

```bash
# Pod resource usage
kubectl top pods -n pickstream

# Node resource usage
kubectl top nodes
```

## Cleanup

```bash
# Delete release
helm uninstall pickstream -n pickstream

# Delete namespace
kubectl delete namespace pickstream

# Delete images from Artifact Registry
gcloud artifacts docker images list us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/pickstream
gcloud artifacts docker images delete us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/pickstream/pickstream-backend:${VERSION}
```

## Troubleshooting

### Pods Not Starting

```bash
# Describe pod
kubectl describe pod <pod-name> -n pickstream

# Check events
kubectl get events -n pickstream --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n pickstream
```

### ImagePullBackOff

```bash
# Verify image exists
gcloud artifacts docker images list us-central1-docker.pkg.dev/${GCP_PROJECT_ID}/pickstream

# Check service account permissions
kubectl get serviceaccount pickstream -n pickstream -o yaml
```

### Service Unavailable

```bash
# Check service endpoints
kubectl get endpoints -n pickstream

# Check pod status
kubectl get pods -n pickstream

# Test connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -n pickstream -- sh
wget -O- http://pickstream-backend:8080/api/health
```

## Best Practices

1. **Always use specific image tags in production** (never `latest`)
2. **Test deployments in dev/staging first**
3. **Monitor resource usage and adjust limits**
4. **Set up alerts for critical metrics**
5. **Regularly update dependencies and base images**
6. **Use Helm secrets for sensitive values**
7. **Implement proper backup strategies**
8. **Document all configuration changes**

## Next Steps

- Set up monitoring with Prometheus and Grafana
- Configure alerting with Alertmanager
- Implement distributed tracing with Jaeger
- Set up log aggregation with Cloud Logging
- Configure backup and disaster recovery
- Implement blue-green or canary deployments
