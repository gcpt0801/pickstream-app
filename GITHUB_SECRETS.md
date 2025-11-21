# GitHub Secrets Configuration

After running the Workload Identity Federation setup commands, add these secrets to your GitHub repository:

**Repository Settings URL:**
https://github.com/gcpt0801/pickstream-app/settings/secrets/actions

## Required Secrets

### 1. WIF_PROVIDER
```
projects/410476324289/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider
```

### 2. WIF_SERVICE_ACCOUNT
```
gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com
```

### 3. GCP_PROJECT_ID
```
gcp-terraform-demo-474514
```

## How to Add Secrets

1. Go to: https://github.com/gcpt0801/pickstream-app/settings/secrets/actions
2. Click "New repository secret"
3. Add each secret with the exact name and value above

## Verify Setup

After adding the secrets, trigger a workflow run to test the authentication.
