variable "environment" {
  type = string
}

variable "kms_key_id" {
  type = string
}

variable "enable_versioning" {
  type    = bool
  default = true
}

data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Environment = var.environment
    Project     = "health-dataops"
    ManagedBy   = "terraform"
  }
  account_id = data.aws_caller_identity.current.account_id

  buckets = {
    raw    = { tier = "raw" }
    bronze = { tier = "bronze" }
    silver = { tier = "silver" }
    gold   = { tier = "gold" }
    logs   = { tier = "logs" }
    dag    = { tier = "mwaa" }
  }
}

resource "aws_s3_bucket" "buckets" {
  for_each = local.buckets
  bucket   = "${var.environment}-health-${each.key == "dag" ? "mwaa-dags" : each.key}-${local.account_id}"
  tags     = merge(local.common_tags, { Name = "${var.environment}-health-${each.key}", Tier = each.value.tier })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "buckets" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.buckets[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.buckets["raw"].id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

output "raw_bucket" {
  value = aws_s3_bucket.buckets["raw"].id
}

output "bronze_bucket" {
  value = aws_s3_bucket.buckets["bronze"].id
}

output "silver_bucket" {
  value = aws_s3_bucket.buckets["silver"].id
}

output "gold_bucket" {
  value = aws_s3_bucket.buckets["gold"].id
}

output "logs_bucket" {
  value = aws_s3_bucket.buckets["logs"].id
}

output "dag_bucket" {
  value = aws_s3_bucket.buckets["dag"].id
}
