# health-dataops

> Production-grade healthcare data pipeline on AWS — HIPAA-oriented, cost-optimized, fully IaC.

[![Terraform](https://img.shields.io/badge/Terraform-≥1.5-7B42BC?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EMR%20%7C%20MWAA%20%7C%20S3%20%7C%20KMS-FF9900?logo=amazonaws)](https://aws.amazon.com/)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## What This Is

A fully automated healthcare data platform built to demonstrate production DataOps patterns — not a tutorial, not a toy. It ingests raw clinical and claims data, transforms it through a medallion architecture (raw → silver → gold), and orchestrates everything with Apache Airflow on managed AWS infrastructure.

Designed for a solo operator or small team. Everything is Terraform. Nothing is clicked in the console.

---

## Architecture

```
GitHub Actions (OIDC)
        │
        ▼
┌───────────────────────────────────────────────────────────┐
│                        AWS VPC (private subnets)          │
│                                                           │
│   S3 Data Lake                  Compute                   │
│   ├── raw/          ◄───────    EMR Cluster (standard)    │
│   ├── silver/       ──────►     EMR Serverless (optimized)│
│   ├── gold/                                               │
│   ├── dags/         ◄───────    MWAA (Airflow)            │
│   └── logs/                          │                    │
│                                      │ orchestrates       │
│   KMS (all buckets encrypted)        ▼                    │
│   CloudWatch (all logs)         Spark Jobs                │
└───────────────────────────────────────────────────────────┘
```

**Medallion layers:**

| Layer | S3 Prefix | Contents |
|-------|-----------|----------|
| Raw | `raw/` | Unmodified source data — claims, ADT, HL7 |
| Silver | `silver/` | Cleaned, validated, deduplicated Parquet |
| Gold | `gold/` | Aggregated, analytics-ready datasets |

---

## Stack

| Category | Technology |
|----------|-----------|
| Orchestration | Apache Airflow via Amazon MWAA |
| Compute | Amazon EMR 6.15 / EMR Serverless |
| Storage | Amazon S3 (multi-tier) |
| Encryption | AWS KMS (SSE-KMS, all buckets) |
| Networking | VPC, private subnets, no public IPs |
| IaC | Terraform ≥ 1.5, S3 backend, DynamoDB locking |
| CI/CD | GitHub Actions with OIDC (no stored AWS keys) |
| Monitoring | CloudWatch Logs, CloudTrail |
| Language | PySpark (jobs), Python (DAGs) |

---

## Security Model

- **No long-lived AWS credentials** — GitHub Actions authenticates via OIDC (`sts:AssumeRoleWithWebIdentity`)
- **All compute in private subnets** — no public IPs on any node
- **KMS encryption at rest** — all S3 buckets, EMR, enforced via bucket policy
- **IAM least-privilege** — separate service, instance, deploy, and Terraform roles; no wildcard principals
- **Audit trail** — CloudTrail + CloudWatch on all services

> HIPAA-oriented architecture. Actual HIPAA compliance requires signed BAAs with AWS and organizational controls outside the scope of this repo.

---

## Repository Layout

```
health-dataops/
├── .github/
│   └── workflows/          # CI/CD pipelines (plan, apply, destroy)
├── airflow/
│   └── dags/               # Airflow DAG definitions
├── data/
│   └── sample/             # Sample input data for local testing
├── infra/
│   ├── environments/
│   │   └── dev/            # Dev environment root (main.tf, variables.tf)
│   └── modules/
│       ├── emr/            # EMR cluster + serverless + IAM
│       ├── iam_github_oidc/ # OIDC provider + deploy roles
│       ├── kms/            # KMS key + alias + policy
│       ├── mwaa/           # Airflow environment + execution role
│       ├── s3_data_lake/   # All buckets + lifecycle policies
│       └── vpc/            # VPC, subnets, NAT, endpoints
├── spark/
│   └── jobs/               # PySpark transformation scripts
└── .env.example
```

---

## Quick Start

**Prerequisites:** AWS CLI configured, Terraform ≥ 1.5, an AWS account.

```bash
# 1. Clone
git clone https://github.com/ccarrylab/health-dataops.git
cd health-dataops

# 2. Bootstrap state backend (one-time)
cd infra/environments/dev
terraform init -backend=false
terraform apply \
  -var="key_admin_arns=[\"$(aws sts get-caller-identity --query Arn --output text)\"]" \
  -target=aws_s3_bucket.terraform_state \
  -target=aws_dynamodb_table.terraform_locks

# 3. Full init with remote backend
terraform init -reconfigure

# 4. Deploy
cp terraform.tfvars.example terraform.tfvars   # fill in your values
terraform apply
```

---

## Cost

Two modes, toggled by `cost_optimized = true/false` in `terraform.tfvars`.

### Production demo (`cost_optimized = false`)

| Service | Cost |
|---------|------|
| MWAA (2–4 workers) | ~$120/month |
| EMR cluster (always-on) | ~$60/day |
| NAT Gateway | ~$32/month |
| **Estimated total** | **~$220/month + EMR** |

### Portfolio / development (`cost_optimized = true`)

| Service | Cost |
|---------|------|
| MWAA (1–2 workers) | ~$40/month |
| EMR Serverless (pay-per-job) | ~$20/month |
| VPC endpoints only | ~$7/month |
| **Estimated total** | **~$67/month** |

---

## Teardown

```bash
cd infra/environments/dev
terraform destroy

# Remove state bucket (irreversible)
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
aws s3 rm s3://health-dataops-terraform-state-${ACCOUNT} --recursive
aws s3api delete-bucket --bucket health-dataops-terraform-state-${ACCOUNT}
```

> Set a calendar reminder before deploying. NAT Gateway and MWAA accrue charges immediately.

---

## CI/CD

GitHub Actions workflows run on pull requests and merges to `main`. Authentication uses OIDC — no AWS access keys are stored in GitHub Secrets.

| Workflow | Trigger | Action |
|----------|---------|--------|
| `terraform-plan.yml` | PR open/update | `terraform plan`, posts diff as comment |
| `terraform-apply.yml` | Merge to `main` | `terraform apply -auto-approve` |

---

## Contributing

Open to feedback and PRs. This is a portfolio project but built to real standards.

---

*Built for health tech. Cost-optimized for job hunting. No tutorials were harmed.*
