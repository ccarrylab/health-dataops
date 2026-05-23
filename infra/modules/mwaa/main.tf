variable "environment"        { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "kms_key_id"         { type = string }
variable "dag_bucket"         { type = string }
variable "cost_optimized"     { type = bool; default = false }

locals {
  common_tags = {
    Environment = var.environment
    Project     = "health-dataops"
    ManagedBy   = "terraform"
  }
  min_workers = var.cost_optimized ? 1 : 2
  max_workers = var.cost_optimized ? 2 : 4

  log_groups = toset(["dag-processing", "scheduler", "task", "webserver", "worker"])
}

resource "aws_cloudwatch_log_group" "mwaa" {
  for_each          = local.log_groups
  name              = "/aws-mwaa/${var.environment}-health-mwaa-${each.key}"
  retention_in_days = 30
  tags              = merge(local.common_tags, { Name = "${var.environment}-mwaa-${each.key}" })
}

resource "aws_iam_role" "mwaa" {
  name = "${var.environment}-mwaa-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow"; Principal = { Service = "airflow.amazonaws.com" }; Action = "sts:AssumeRole" }]
  })
  tags = merge(local.common_tags, { Name = "${var.environment}-mwaa-execution-role" })
}

resource "aws_iam_role_policy_attachment" "mwaa_basic" {
  role = aws_iam_role.mwaa.name; policy_arn = "arn:aws:iam::aws:policy/AmazonMWAAFullAccess"
}
resource "aws_iam_role_policy_attachment" "mwaa_s3" {
  role = aws_iam_role.mwaa.name; policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_role_policy_attachment" "mwaa_cloudwatch" {
  role = aws_iam_role.mwaa.name; policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
resource "aws_iam_role_policy_attachment" "mwaa_ec2" {
  role = aws_iam_role.mwaa.name; policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_security_group" "mwaa" {
  name        = "${var.environment}-mwaa-sg"
  description = "MWAA security group"
  vpc_id      = var.vpc_id
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
  tags = merge(local.common_tags, { Name = "${var.environment}-mwaa-sg" })
}

resource "aws_mwaa_environment" "main" {
  name               = "${var.environment}-health-mwaa"
  execution_role_arn = aws_iam_role.mwaa.arn
  source_bucket_arn  = "arn:aws:s3:::${var.dag_bucket}"
  min_workers        = local.min_workers
  max_workers        = local.max_workers

  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = var.private_subnet_ids
  }

  logging_configuration {
    dag_processing_logs { enabled = true; log_level = "INFO"; cloud_watch_log_group_arn = aws_cloudwatch_log_group.mwaa["dag-processing"].arn }
    scheduler_logs      { enabled = true; log_level = "INFO"; cloud_watch_log_group_arn = aws_cloudwatch_log_group.mwaa["scheduler"].arn }
    task_logs           { enabled = true; log_level = "INFO"; cloud_watch_log_group_arn = aws_cloudwatch_log_group.mwaa["task"].arn }
    webserver_logs      { enabled = true; log_level = "INFO"; cloud_watch_log_group_arn = aws_cloudwatch_log_group.mwaa["webserver"].arn }
    worker_logs         { enabled = true; log_level = "INFO"; cloud_watch_log_group_arn = aws_cloudwatch_log_group.mwaa["worker"].arn }
  }

  tags = merge(local.common_tags, { Name = "${var.environment}-health-mwaa" })
}

output "environment_name" { value = aws_mwaa_environment.main.name }
output "environment_arn"  { value = aws_mwaa_environment.main.arn }
output "webserver_url"    { value = aws_mwaa_environment.main.webserver_url }
