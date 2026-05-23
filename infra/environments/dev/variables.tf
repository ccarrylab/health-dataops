variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "github_org" {
  type    = string
  default = "ccarrylab"
}

variable "github_repo" {
  type    = string
  default = "health-dataops"
}

variable "key_admin_arns" {
  type = list(string)
}

variable "cost_optimized" {
  type    = bool
  default = true
}
