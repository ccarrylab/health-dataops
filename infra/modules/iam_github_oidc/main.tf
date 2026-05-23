variable "environment"  { type = string }
variable "github_org"   { type = string; default = "your-github-org" }
variable "github_repo"  { type = string; default = "your-repo-name" }

locals {
  common_tags = {
    Environment = var.environment
    Project     = "health-dataops"
    ManagedBy   = "terraform"
  }
  gh_sub = "repo:${var.github_org}/${var.github_repo}:*"
}

data "tls_certificate" "github" { url = "https://token.actions.githubusercontent.com" }

resource "aws_iam_openid_connect_provider" "github" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  url             = "https://token.actions.githubusercontent.com"
  tags            = merge(local.common_tags, { Name = "${var.environment}-github-oidc" })
}

resource "aws_iam_role" "terraform" {
  name = "${var.environment}-github-terraform-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = local.gh_sub }
      }
    }]
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
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = local.gh_sub }
      }
    }]
  })
  tags = merge(local.common_tags, { Name = "${var.environment}-github-deploy-role" })
}

resource "aws_iam_role_policy_attachment" "deploy_s3"   {
  role = aws_iam_role.deploy.name; policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_role_policy_attachment" "deploy_mwaa" {
  role = aws_iam_role.deploy.name; policy_arn = "arn:aws:iam::aws:policy/AmazonMWAAFullAccess"
}

output "github_oidc_arn"    { value = aws_iam_openid_connect_provider.github.arn }
output "terraform_role_arn" { value = aws_iam_role.terraform.arn }
output "deploy_role_arn"    { value = aws_iam_role.deploy.arn }
