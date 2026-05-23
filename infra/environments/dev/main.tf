terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket         = "health-dataops-terraform-state-089719647189"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "health-dataops-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = { Project = "health-dataops"; Environment = var.environment; ManagedBy = "terraform" } }
}

variable "environment"     { type = string; default = "dev" }
variable "aws_region"      { type = string; default = "us-east-1" }
variable "github_org"      { type = string; default = "ccarrylab" }
variable "github_repo"     { type = string; default = "health-dataops" }
variable "key_admin_arns"  { type = list(string) }
variable "cost_optimized"  { type = bool; default = true }

module "vpc"             { source = "../../modules/vpc";            environment = var.environment; vpc_cidr = "10.0.0.0/16"; aws_region = var.aws_region }
module "kms"             { source = "../../modules/kms";            environment = var.environment; key_admins = var.key_admin_arns }
module "s3_data_lake"    { source = "../../modules/s3_data_lake";   environment = var.environment; kms_key_id = module.kms.key_id }
module "iam_github_oidc" { source = "../../modules/iam_github_oidc"; environment = var.environment; github_org = var.github_org; github_repo = var.github_repo }

module "emr" {
  source             = "../../modules/emr"
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  kms_key_id         = module.kms.key_id
  logs_bucket        = module.s3_data_lake.logs_bucket
  use_serverless     = var.cost_optimized
}

module "mwaa" {
  source             = "../../modules/mwaa"
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  kms_key_id         = module.kms.key_id
  dag_bucket         = module.s3_data_lake.dag_bucket
  cost_optimized     = var.cost_optimized
}

output "vpc_id"                { value = module.vpc.vpc_id }
output "terraform_role_arn"    { value = module.iam_github_oidc.terraform_role_arn }
output "deploy_role_arn"       { value = module.iam_github_oidc.deploy_role_arn }
output "mwaa_webserver_url"    { value = module.mwaa.webserver_url }
output "emr_cluster_id"        { value = module.emr.cluster_id }
output "emr_serverless_app_id" { value = module.emr.serverless_app_id }
output "raw_bucket"            { value = module.s3_data_lake.raw_bucket }
output "curated_bucket"        { value = module.s3_data_lake.gold_bucket }
output "artifact_bucket"       { value = module.s3_data_lake.silver_bucket }
output "dag_bucket"            { value = module.s3_data_lake.dag_bucket }
