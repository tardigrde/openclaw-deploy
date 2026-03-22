---
title: "Remote State"
weight: 30
aliases: ["/remote-state/"]
---
# Remote State Backend

By default Terraform uses a **local backend** (`terraform.tfstate` on disk). This requires zero setup and works fine for solo use. For team workflows or CI/CD, a remote backend gives you shared state, versioning, and locking.

## Choosing a Backend

`terraform/envs/prod/backend.tf` (copied from `backend.tf.example`) controls the backend:

```hcl
# Option A — Local (default, no setup required)
terraform {
  backend "local" {}
}

# Option B — GCS (recommended for teams / CI)
terraform {
  backend "gcs" {
    bucket = "your-project-tfstate"
    prefix = "openclaw/prod"
  }
}
```

Terraform supports other backends too (S3, Azure Blob, Terraform Cloud). Any Terraform-compatible backend works — update `backend.tf` accordingly. Note that S3 requires a separate DynamoDB table for state locking, whereas GCS locks natively.

## GCS Setup

GCS is the recommended remote backend: free tier covers Terraform state (5 GB, 5K/50K ops/month), native locking with no extra services, and automatic encryption at rest.

**1. Install the [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)**

**2. Create a GCP project with billing:**

```bash
gcloud projects create my-project --set-as-default
gcloud billing projects link my-project --billing-account=<ACCOUNT_ID>
```

**3. Enable Cloud Storage and authenticate:**

```bash
gcloud services enable storage.googleapis.com
gcloud auth application-default login
```

**4. Create the bucket:**

```bash
gsutil mb -p <project> -l us-east1 -b on gs://<project>-tfstate
gsutil versioning set on gs://<project>-tfstate
```

**5. Update `backend.tf`** with your bucket name (Option B above).

## Migrating from Local State

If you've already run `make apply` with the local backend:

```bash
cd terraform/envs/prod
terraform init -migrate-state
```

Terraform will prompt you to copy local state to the remote backend.

## CI Authentication (GCS + WIF)

The included Terraform CI workflows authenticate to GCS via keyless Workload Identity Federation — no service account JSON needed. Set these GitHub repository variables:

| Variable | Value |
|----------|-------|
| `GCP_WIF_PROVIDER` | Full WIF provider resource name (e.g. `projects/<n>/locations/global/workloadIdentityPools/github/providers/github`) |
| `GCP_SERVICE_ACCOUNT` | Automation SA email (e.g. `automation@<project>.iam.gserviceaccount.com`) |

See [Configuring OIDC in GCP](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-google-cloud-platform) for WIF setup instructions.
