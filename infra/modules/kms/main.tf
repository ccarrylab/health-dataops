variable "environment" { type = string }
variable "key_admins"  { type = list(string) }

locals {
  common_tags = {
    Environment = var.environment
    Project     = "health-dataops"
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "data" {
  description             = "KMS key for health data encryption (${var.environment})"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = var.key_admins }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "Allow CloudWatch Logs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_caller_identity.current.partition}.amazonaws.com" }
        Action    = ["kms:CreateGrant", "kms:DescribeKey"]
        Resource  = "*"
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${var.environment}-health-data-key", Type = "data" })
}

resource "aws_kms_alias" "data" {
  name          = "alias/${var.environment}-health-data-key"
  target_key_id = aws_kms_key.data.key_id
}

output "key_id"  { value = aws_kms_key.data.id }
output "key_arn" { value = aws_kms_key.data.arn }
