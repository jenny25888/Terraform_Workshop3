# Terraform AWS Load Balancer Project

This project deploys a scalable web server infrastructure on AWS using Terraform, featuring multiple EC2 instances behind an Application Load Balancer (ALB).

## Architecture

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                        VPC                              │
                    │                    10.0.0.0/16                          │
                    │                                                         │
    Internet        │   ┌─────────────────────────────────────────────────┐   │
        │           │   │            Application Load Balancer            │   │
        │           │   │              (terraform-web-alb)                │   │
        ▼           │   └─────────────────────────────────────────────────┘   │
┌───────────────┐   │                    │                │                   │
│    Internet   │───│────────────────────┼────────────────┼───────────────────│
│    Gateway    │   │                    ▼                ▼                   │
└───────────────┘   │   ┌─────────────────────┐  ┌─────────────────────┐      │
                    │   │   Subnet 1 (AZ-a)   │  │   Subnet 2 (AZ-b)   │      │
                    │   │    10.0.1.0/24      │  │    10.0.2.0/24      │      │
                    │   │                     │  │                     │      │
                    │   │  ┌───────────────┐  │  │  ┌───────────────┐  │      │
                    │   │  │  EC2 Instance │  │  │  │  EC2 Instance │  │      │
                    │   │  │  (Apache)     │  │  │  │  (Apache)     │  │      │
                    │   │  └───────────────┘  │  │  └───────────────┘  │      │
                    │   └─────────────────────┘  └─────────────────────┘      │
                    └─────────────────────────────────────────────────────────┘
```

## Features

- **Multiple EC2 Instances**: Configurable number of web server instances
- **Application Load Balancer**: Distributes traffic across instances
- **High Availability**: Instances deployed across multiple Availability Zones
- **Auto Health Checks**: ALB monitors instance health
- **CI/CD Integration**: GitHub Actions workflows for automated deployment

## Prerequisites

- AWS Account (AWS Academy Learner Lab)
- Terraform >= 1.2
- Terraform Cloud Account (kostenlos)
- GitHub Account (für CI/CD)

---

## Terraform Cloud Setup

Terraform Cloud speichert den **State** zentral und ermöglicht sichere CI/CD-Pipelines.

### 1. Terraform Cloud Account erstellen

1. Gehe zu [app.terraform.io](https://app.terraform.io)
2. Erstelle einen kostenlosen Account
3. Erstelle eine **Organization** (z.B. `mein-name-org`)

### 2. Workspace erstellen

1. In Terraform Cloud: **Projects & workspaces** → **New Workspace**
2. Wähle **API-driven workflow**
3. Name: `aws-loadbalancer`
4. Klicke **Create workspace**

### 3. Execution Mode auf "Local" setzen

⚠️ **Wichtig**: Da wir GitHub Actions für die Ausführung nutzen:

1. Gehe zu deinem Workspace → **Settings** → **General**
2. Unter **Execution Mode** wähle: **Local**
3. Klicke **Save settings**

> Bei "Local" Mode speichert Terraform Cloud nur den State, während GitHub Actions die Terraform-Befehle ausführt.

### 4. API Token erstellen

Für GitHub Actions brauchst du einen API Token:

1. Klicke auf dein **Profilbild** (oben rechts) → **User Settings**
2. **Tokens** → **Create an API token**
3. Description: `GitHub Actions`
4. Kopiere den Token (wird nur einmal angezeigt!)

### 5. Konfiguration anpassen

In `main.tf` deine Organisation eintragen:

```hcl
cloud {
  organization = "DEINE-ORGANISATION"  # <- Hier ändern!

  workspaces {
    name = "aws-loadbalancer"
  }
}
```

---

## GitHub Setup

### Setup GitHub Secrets

Du brauchst **4 Secrets** in GitHub (Settings → Secrets → Actions):

| Secret Name | Beschreibung | Wo zu finden |
|-------------|--------------|--------------|
| `TF_API_TOKEN` | Terraform Cloud API Token | Terraform Cloud → User Settings → Tokens |
| `AWS_ACCESS_KEY_ID` | AWS Access Key | AWS Academy → AWS Details → Show |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key | AWS Academy → AWS Details → Show |
| `AWS_SESSION_TOKEN` | AWS Session Token | AWS Academy → AWS Details → Show |

### Credentials in AWS Academy finden

```
┌─────────────────────────────────────────────────────┐
│  AWS Academy Learner Lab                            │
│                                                     │
│  [Start Lab]  [AWS 🟢]  [AWS Details] ← Klicken     │
│                              │                      │
│                              ▼                      │
│  ┌─────────────────────────────────────────────┐   │
│  │ AWS CLI:  [Show] ← Dann hier                │   │
│  │                                             │   │
│  │ [default]                                   │   │
│  │ aws_access_key_id=ASIAX...                  │   │
│  │ aws_secret_access_key=abc123...             │   │
│  │ aws_session_token=FwoGZX...                 │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### ⚠️ Wichtig bei AWS Academy

- Credentials sind nur **~4 Stunden gültig**
- Nach Lab-Neustart: **GitHub Secrets aktualisieren**
- Lab muss **laufen** (grüner Punkt) während Workflows laufen

## Local Usage

```bash
# Login to Terraform Cloud (einmalig)
terraform login

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply

# Destroy resources
terraform destroy
```

### Customizing Instance Count

```bash
# Create 3 instances instead of default 2
terraform apply -var="instance_count=3"
```

---

## CI/CD Usage (GitHub Actions)

### Running Workflows

1. **Deploy Infrastructure**: 
   - Go to Actions → "Terraform Apply" → Run workflow
   - Optionally specify the number of instances

2. **Destroy Infrastructure**: 
   - Go to Actions → "Terraform Destroy" → Run workflow
   - Type `destroy` to confirm

---

## Outputs

| Output | Description |
|--------|-------------|
| `instance_ids` | IDs of created EC2 instances |
| `instance_private_ips` | Private IPs of EC2 instances |
| `load_balancer_dns` | DNS name of the ALB |
| `load_balancer_url` | Full URL to access the application |

---

## Why Do We Need Terraform Cloud (or Another Backend) When Using CI/CD?

When using Terraform with CI/CD pipelines, a remote backend like **Terraform Cloud**, **AWS S3**, or **Azure Blob Storage** is essential for several critical reasons:

### 1. State File Management

Terraform maintains a **state file** (`terraform.tfstate`) that tracks all managed resources. This file is crucial because:

- It maps real-world resources to your configuration
- It stores metadata and resource dependencies
- It enables Terraform to determine what changes need to be made

**Problem without remote backend**: In CI/CD, each pipeline run starts fresh. Without a shared backend, Terraform cannot find the previous state file, causing it to:
- Think no resources exist
- Attempt to create duplicate resources
- Lose track of existing infrastructure

### 2. State Locking

When multiple team members or CI/CD runs execute Terraform simultaneously:

**Problem**: Concurrent operations can corrupt the state file or create conflicting resources.

**Solution**: Remote backends provide **state locking**, ensuring only one operation can modify the state at a time.

```
Pipeline Run 1: terraform apply ──► Acquires Lock ──► Makes Changes ──► Releases Lock
Pipeline Run 2: terraform apply ──► Waits for Lock ──────────────────► Acquires Lock ──► ...
```

### 3. Team Collaboration

- **Shared State**: All team members and CI/CD pipelines access the same state
- **Consistency**: Everyone works with the current infrastructure state
- **Audit Trail**: Terraform Cloud maintains state version history

### 4. Security

Storing state locally in CI/CD is problematic:

- State files may contain **sensitive data** (passwords, keys, IPs)
- Local files are lost when runners terminate
- No encryption or access control

Remote backends provide:
- Encryption at rest and in transit
- Access control policies
- Secure credential management

### 5. Practical Example

**Without Remote Backend:**
```
Day 1: CI/CD creates 2 EC2 instances (state stored locally, then lost)
Day 2: CI/CD runs again, creates 2 MORE instances (no state = no knowledge of Day 1)
Result: 4 instances, orphaned resources, wasted money
```

**With Remote Backend:**
```
Day 1: CI/CD creates 2 EC2 instances, stores state in Terraform Cloud
Day 2: CI/CD reads state from Terraform Cloud, knows about existing instances
Result: Only necessary changes are made
```

### Summary Table

| Feature | Local State | Remote Backend |
|---------|-------------|----------------|
| Persistence across runs | ❌ | ✅ |
| State locking | ❌ | ✅ |
| Team collaboration | ❌ | ✅ |
| Encryption | ❌ | ✅ |
| Version history | ❌ | ✅ |
| CI/CD compatible | ❌ | ✅ |

### Recommended Backends for CI/CD

1. **Terraform Cloud** - Best for teams, includes free tier
2. **AWS S3 + DynamoDB** - Good for AWS-centric teams
3. **Azure Blob Storage** - Good for Azure-centric teams
4. **Google Cloud Storage** - Good for GCP-centric teams

---

## License

MIT License
