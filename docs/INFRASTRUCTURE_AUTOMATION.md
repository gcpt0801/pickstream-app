# Infrastructure Automation Requirements

This document details all the manual infrastructure setup that needs to be automated in the `pickstream-infrastructure` Terraform repository.

## Current State

The existing `pickstream-infrastructure` repo has:
- ✅ GKE cluster creation
- ✅ Networking (VPC, subnets)
- ✅ Basic IAM setup

## Missing Infrastructure (Manual Steps to Automate)

### 1. Artifact Registry

**Manual command used:**
```bash
gcloud artifacts repositories create pickstream \
    --repository-format=docker \
    --location=us-central1 \
    --description="Docker repository for Pickstream microservices"
```

**Terraform module needed:**
Create `terraform/modules/artifact-registry/main.tf`:

```hcl
resource "google_artifact_registry_repository" "pickstream" {
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = "DOCKER"

  docker_config {
    immutable_tags = var.immutable_tags
  }

  labels = var.labels
}

# IAM binding for GKE nodes to pull images
resource "google_artifact_registry_repository_iam_member" "gke_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.pickstream.location
  repository = google_artifact_registry_repository.pickstream.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.gke_node_service_account}"
}

# IAM binding for GitHub Actions to push images
resource "google_artifact_registry_repository_iam_member" "github_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.pickstream.location
  repository = google_artifact_registry_repository.pickstream.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.github_service_account}"
}
```

**Variables (`terraform/modules/artifact-registry/variables.tf`):**
```hcl
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "location" {
  description = "Artifact Registry location"
  type        = string
  default     = "us-central1"
}

variable "repository_id" {
  description = "Artifact Registry repository ID"
  type        = string
  default     = "pickstream"
}

variable "description" {
  description = "Repository description"
  type        = string
  default     = "Docker repository for Pickstream microservices"
}

variable "immutable_tags" {
  description = "Enable immutable tags"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to the repository"
  type        = map(string)
  default     = {}
}

variable "gke_node_service_account" {
  description = "Service account email for GKE nodes"
  type        = string
}

variable "github_service_account" {
  description = "Service account email for GitHub Actions"
  type        = string
}
```

**Outputs (`terraform/modules/artifact-registry/outputs.tf`):**
```hcl
output "repository_id" {
  description = "Artifact Registry repository ID"
  value       = google_artifact_registry_repository.pickstream.repository_id
}

output "repository_url" {
  description = "Full repository URL"
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.pickstream.repository_id}"
}

output "location" {
  description = "Repository location"
  value       = google_artifact_registry_repository.pickstream.location
}
```

---

### 2. Workload Identity Federation

**Manual commands used:**
```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create github-pool \
    --location="global" \
    --description="Workload Identity Pool for GitHub Actions" \
    --display-name="GitHub Pool"

# Create Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc github-provider \
    --location="global" \
    --workload-identity-pool="github-pool" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
    --attribute-condition="assertion.repository_owner == 'gcpt0801'"

# Bind service account to Workload Identity
gcloud iam service-accounts add-iam-policy-binding gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/410476324289/locations/global/workloadIdentityPools/github-pool/attribute.repository/gcpt0801/pickstream-app"
```

**Terraform module needed:**
Create `terraform/modules/workload-identity/main.tf`:

```hcl
# Workload Identity Pool
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = var.pool_id
  display_name              = var.pool_display_name
  description               = var.pool_description
  disabled                  = false
}

# OIDC Provider for GitHub Actions
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = var.provider_display_name
  description                        = var.provider_description
  disabled                           = false

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = var.attribute_condition

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Bind service account to Workload Identity
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = var.service_account_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}
```

**Variables (`terraform/modules/workload-identity/variables.tf`):**
```hcl
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "pool_id" {
  description = "Workload Identity Pool ID"
  type        = string
  default     = "github-pool"
}

variable "pool_display_name" {
  description = "Display name for the pool"
  type        = string
  default     = "GitHub Pool"
}

variable "pool_description" {
  description = "Description for the pool"
  type        = string
  default     = "Workload Identity Pool for GitHub Actions"
}

variable "provider_id" {
  description = "Workload Identity Provider ID"
  type        = string
  default     = "github-provider"
}

variable "provider_display_name" {
  description = "Display name for the provider"
  type        = string
  default     = "GitHub Provider"
}

variable "provider_description" {
  description = "Description for the provider"
  type        = string
  default     = "OIDC provider for GitHub Actions"
}

variable "attribute_condition" {
  description = "Attribute condition to restrict which GitHub repos can authenticate"
  type        = string
  default     = ""
}

variable "service_account_name" {
  description = "Full service account resource name (projects/{project}/serviceAccounts/{email})"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
}
```

**Outputs (`terraform/modules/workload-identity/outputs.tf`):**
```hcl
output "pool_id" {
  description = "Workload Identity Pool ID"
  value       = google_iam_workload_identity_pool.github.workload_identity_pool_id
}

output "pool_name" {
  description = "Workload Identity Pool full resource name"
  value       = google_iam_workload_identity_pool.github.name
}

output "provider_id" {
  description = "Workload Identity Provider ID"
  value       = google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id
}

output "provider_name" {
  description = "Workload Identity Provider full resource name"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "workload_identity_provider" {
  description = "Full workload identity provider for GitHub Actions"
  value       = "projects/${var.project_id}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id}"
}
```

---

### 3. Service Accounts with Proper Roles

**Manual commands used:**
```bash
# GitHub Actions service account (already exists, just add roles)
gcloud projects add-iam-policy-binding gcp-terraform-demo-474514 \
    --member="serviceAccount:gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding gcp-terraform-demo-474514 \
    --member="serviceAccount:gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com" \
    --role="roles/container.developer"

# GKE node service account
gcloud projects add-iam-policy-binding gcp-terraform-demo-474514 \
    --member="serviceAccount:pickstream-cluster-nodes-sa@gcp-terraform-demo-474514.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.reader"
```

**Update existing IAM module:**
Enhance `terraform/modules/iam/main.tf` to include:

```hcl
# GitHub Actions Service Account
resource "google_service_account" "github_actions" {
  account_id   = var.github_sa_name
  display_name = var.github_sa_display_name
  description  = "Service account for GitHub Actions CI/CD"
  project      = var.project_id
}

# GitHub Actions IAM roles
resource "google_project_iam_member" "github_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_container_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# GKE Node Service Account IAM roles
resource "google_project_iam_member" "gke_artifact_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${var.gke_node_service_account}"
}
```

---

### 4. Firewall Rules for LoadBalancer

**Manual command used:**
```bash
gcloud compute firewall-rules create allow-loadbalancer-http \
    --network=pickstream-cluster-network \
    --allow=tcp:80,tcp:443 \
    --source-ranges=0.0.0.0/0 \
    --description="Allow HTTP/HTTPS traffic to LoadBalancer services"
```

**Update networking module:**
Enhance `terraform/modules/networking/main.tf` to include:

```hcl
# Firewall rule for LoadBalancer HTTP/HTTPS traffic
resource "google_compute_firewall" "loadbalancer_http" {
  name    = "${var.network_name}-allow-loadbalancer-http"
  network = google_compute_network.vpc.name
  project = var.project_id

  description = "Allow HTTP/HTTPS traffic to LoadBalancer services"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = var.loadbalancer_tags
}

# Health check firewall rule (GCP health checks come from specific ranges)
resource "google_compute_firewall" "loadbalancer_health_check" {
  name    = "${var.network_name}-allow-health-check"
  network = google_compute_network.vpc.name
  project = var.project_id

  description = "Allow Google Cloud health checks"

  allow {
    protocol = "tcp"
  }

  source_ranges = [
    "35.191.0.0/16",    # Google Cloud health check ranges
    "130.211.0.0/22"
  ]
  target_tags = var.loadbalancer_tags
}
```

---

## Integration in Dev Environment

Update `terraform/environments/dev/main.tf` to include all new modules:

```hcl
# Existing modules...
module "networking" {
  # ... existing config
}

module "gke" {
  # ... existing config
}

# NEW: Artifact Registry
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id                = var.project_id
  location                  = var.region
  repository_id             = "pickstream"
  gke_node_service_account  = module.gke.node_service_account
  github_service_account    = module.iam.github_service_account_email

  labels = {
    environment = "dev"
    managed_by  = "terraform"
  }
}

# NEW: Workload Identity Federation
module "workload_identity" {
  source = "../../modules/workload-identity"

  project_id            = var.project_id
  github_repository     = var.github_repository
  service_account_name  = module.iam.github_service_account_name
  attribute_condition   = "assertion.repository_owner == '${var.github_org}'"
}

# Enhanced IAM module with new roles
module "iam" {
  source = "../../modules/iam"

  project_id                = var.project_id
  github_sa_name            = "gcp-terraform-demo"
  github_sa_display_name    = "GitHub Actions Service Account"
  gke_node_service_account  = module.gke.node_service_account
}
```

**Add new variables to `terraform/environments/dev/variables.tf`:**

```hcl
variable "github_repository" {
  description = "GitHub repository for Workload Identity (owner/repo)"
  type        = string
  default     = "gcpt0801/pickstream-app"
}

variable "github_org" {
  description = "GitHub organization/owner"
  type        = string
  default     = "gcpt0801"
}
```

**Update `terraform/environments/dev/outputs.tf`:**

```hcl
# Existing outputs...

# Artifact Registry outputs
output "artifact_registry_url" {
  description = "Artifact Registry repository URL"
  value       = module.artifact_registry.repository_url
}

# Workload Identity outputs
output "workload_identity_provider" {
  description = "Workload Identity Provider for GitHub Actions"
  value       = module.workload_identity.workload_identity_provider
}

output "github_service_account_email" {
  description = "GitHub Actions service account email"
  value       = module.iam.github_service_account_email
}
```

---

## Implementation Steps

### Step 1: Create New Modules

```bash
cd pickstream-infrastructure/terraform/modules

# Create Artifact Registry module
mkdir artifact-registry
touch artifact-registry/{main.tf,variables.tf,outputs.tf}

# Create Workload Identity module
mkdir workload-identity
touch workload-identity/{main.tf,variables.tf,outputs.tf}
```

### Step 2: Copy Module Code

Copy the Terraform code from this document into the respective files.

### Step 3: Update Existing Modules

- Update `modules/iam/main.tf` with GitHub Actions roles
- Update `modules/networking/main.tf` with firewall rules
- Update `modules/gke/outputs.tf` to export node service account

### Step 4: Update Dev Environment

- Update `environments/dev/main.tf` to use new modules
- Add new variables to `environments/dev/variables.tf`
- Add new outputs to `environments/dev/outputs.tf`

### Step 5: Plan and Apply

```bash
cd terraform/environments/dev

terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 6: Verify Outputs

After successful apply, get the Workload Identity Provider:

```bash
terraform output workload_identity_provider
# Use this in GitHub Actions workflow
```

---

## Benefits of Automation

1. **Reproducibility**: Infrastructure can be recreated from scratch
2. **Version Control**: All infrastructure changes tracked in Git
3. **Documentation**: Terraform code serves as living documentation
4. **Consistency**: Same setup across dev/staging/prod environments
5. **Disaster Recovery**: Quick recovery from infrastructure loss
6. **Audit Trail**: Clear history of who changed what and when

---

## Security Considerations

1. **Least Privilege**: Service accounts only get necessary roles
2. **Workload Identity**: Keyless authentication (no service account keys)
3. **Attribute Conditions**: Restrict which GitHub repos can authenticate
4. **Immutable Tags**: Optional for production Artifact Registry
5. **Network Policies**: Can be re-enabled with proper DNS egress rules

---

## Next Steps After Automation

1. Remove manual firewall creation from `pickstream-app` CI/CD
2. Update GitHub Actions to use Terraform outputs
3. Document the infrastructure setup process
4. Add pre-commit hooks for Terraform validation
5. Set up remote state backend (GCS) for team collaboration

---

## Testing Checklist

After implementing these changes:

- [ ] Terraform plan shows no errors
- [ ] All modules initialize successfully
- [ ] Artifact Registry created with proper IAM
- [ ] Workload Identity Pool and Provider created
- [ ] GitHub Actions can authenticate without keys
- [ ] GKE nodes can pull images from Artifact Registry
- [ ] LoadBalancer firewall rules allow HTTP/HTTPS
- [ ] All outputs are populated correctly
- [ ] `pickstream-app` CI/CD pipeline works without manual steps

---

## References

- [Terraform Google Provider Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Workload Identity Federation Guide](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)
- [GKE Service Account Best Practices](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa)
