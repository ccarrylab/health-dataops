# Development Guide

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured (`aws configure`)
- Python 3.11+
- pre-commit (`pip install pre-commit`)

## Setup

```bash
# Install pre-commit hooks
pre-commit install

# Copy and fill in your variables
cp infra/environments/dev/terraform.tfvars.example infra/environments/dev/terraform.tfvars
```

## Common Commands

```bash
make bootstrap   # create S3 state bucket + DynamoDB lock table (first time only)
make init        # terraform init with remote backend
make plan        # preview changes
make apply       # deploy
make destroy     # tear everything down
```

## Running Spark Jobs Locally

```bash
pip install pyspark==3.5.0
cd spark/jobs
python claims_transform.py --input ../../data/sample/ --output /tmp/output/
```

## Testing DAGs Locally

```bash
pip install apache-airflow==2.9.0
export AIRFLOW_HOME=$(pwd)/airflow
airflow db init
airflow dags test health_pipeline 2026-01-01
```

## Cost Warning

MWAA and NAT Gateway bill immediately on creation.
Always run `make destroy` when done.
Set a calendar reminder.
