terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

variable "environment" {
  type = string
}

variable "github_org" {
  type    = string
  default = "your-github-org"
}

variable "github_repo" {
  type    = string
  default = "your-repo-name"
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = "health-dataops"
    ManagedBy   = "terraform"
  }
  gh_sub = "repo:${var.github_org}/${var.github_repo}:*"
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# FIX 3: One OIDC provider can exist per URL per AWS account.
# Use a data source to reference it if it already exists,
# and only create it if this is the first environment being deployed.
# Alternatively, manage this resource outside of per-environment configs.
resource "aws_iam_openid_connect_provider" "github" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  url             = "https://token.actions.githubusercontent.com"
  tags            = merge(local.common_tags, { Name = "github-oidc" })

  lifecycle {
    # Prevent accidental deletion; this is shared across environments
    prevent_destroy = true
  }
}

resource "aws_iam_role" "terraform" {
  name = "${var.environment}-github-terraform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
          StringLike   = { "token.actions.githubusercontent.com:sub" = local.gh_sub }
        }
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${var.environment}-github-terraform-role" })
}

resource "aws_iam_role_policy_attachment" "terraform_admin" {
  role       = aws_iam_role.terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "deploy" {
  name = "${var.environment}-github-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
          StringLike   = { "token.actions.githubusercontent.com:sub" = local.gh_sub }
        }
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${var.environment}-github-deploy-role" })
}

resource "aws_iam_role_policy_attachment" "deploy_s3" {
  role       = aws_iam_role.deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "deploy_mwaa" {
  role       = aws_iam_role.deploy.name
  # FIX 1: AmazonMWAAFullAccess does not exist — correct policy name:
  policy_arn = "arn:aws:iam::aws:policy/AmazonMWAAFullConsoleAccess"
}

output "github_oidc_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "terraform_role_arn" {
  value = aws_iam_role.terraform.arn
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}