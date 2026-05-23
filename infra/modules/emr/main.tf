variable "environment"        { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "kms_key_id"         { type = string }
variable "logs_bucket"        { type = string }
variable "use_serverless" {
  type    = bool
  default = false
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = "health-dataops"
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "emr_master" {
  count       = var.use_serverless ? 0 : 1
  name        = "${var.environment}-emr-master"
  description = "EMR master security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.environment}-emr-master-sg" })
}

resource "aws_security_group" "emr_slave" {
  count       = var.use_serverless ? 0 : 1
  name        = "${var.environment}-emr-slave"
  description = "EMR slave security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.environment}-emr-slave-sg" })
}

resource "aws_security_group_rule" "master_from_slave" {
  count                    = var.use_serverless ? 0 : 1
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.emr_master[0].id
  source_security_group_id = aws_security_group.emr_slave[0].id
}

resource "aws_security_group_rule" "slave_from_master" {
  count                    = var.use_serverless ? 0 : 1
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.emr_slave[0].id
  source_security_group_id = aws_security_group.emr_master[0].id
}

resource "aws_iam_role" "emr_service" {
  count = var.use_serverless ? 0 : 1
  name  = "${var.environment}-emr-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "elasticmapreduce.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = merge(local.common_tags, { Name = "${var.environment}-emr-service-role" })
}

resource "aws_iam_role_policy_attachment" "emr_service_policy" {
  count      = var.use_serverless ? 0 : 1
  role       = aws_iam_role.emr_service[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRServicePolicyV2"
}

resource "aws_iam_role" "emr_instance" {
  count = var.use_serverless ? 0 : 1
  name  = "${var.environment}-emr-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = merge(local.common_tags, { Name = "${var.environment}-emr-instance-role" })
}

resource "aws_iam_role_policy_attachment" "emr_instance_s3" {
  count      = var.use_serverless ? 0 : 1
  role       = aws_iam_role.emr_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "emr_instance_cw" {
  count      = var.use_serverless ? 0 : 1
  role       = aws_iam_role.emr_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_instance_profile" "emr" {
  count = var.use_serverless ? 0 : 1
  name  = "${var.environment}-emr-instance-profile"
  role  = aws_iam_role.emr_instance[0].name
}

resource "aws_emr_security_configuration" "main" {
  count = var.use_serverless ? 0 : 1
  name  = "${var.environment}-health-emr-security"
  configuration = jsonencode({
    EncryptionConfiguration = {
      EncryptionAtRestConfiguration = {
        S3EncryptionConfiguration = {
          EncryptionMode = "SSE-KMS"
          KmsKeyArn      = var.kms_key_id
        }
      }
      EnableHdfsEncryption = false
    }
  })
}

resource "aws_emr_cluster" "main" {
  count         = var.use_serverless ? 0 : 1
  name          = "${var.environment}-health-emr-cluster"
  release_label = "emr-6.15.0"
  applications  = ["Spark", "Hadoop", "Hive"]

  ec2_attributes {
    emr_managed_master_security_group = aws_security_group.emr_master[0].id
    emr_managed_slave_security_group  = aws_security_group.emr_slave[0].id
    subnet_id                         = var.private_subnet_ids[0]
    instance_profile                  = aws_iam_instance_profile.emr[0].name
  }

  master_instance_group {
    instance_type = "m5.xlarge"
  }

  core_instance_group {
    instance_type  = "m5.xlarge"
    instance_count = 2
    bid_price      = "0.30"
  }

  service_role           = aws_iam_role.emr_service[0].name
  security_configuration = aws_emr_security_configuration.main[0].name

  termination_protection            = false
  keep_job_flow_alive_when_no_steps = true
  log_uri                           = "s3://${var.logs_bucket}/logs/emr/"

  tags = merge(local.common_tags, { Name = "${var.environment}-health-emr" })
}

resource "aws_security_group" "emr_serverless" {
  count       = var.use_serverless ? 1 : 0
  name        = "${var.environment}-emr-serverless-sg"
  description = "EMR Serverless security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.environment}-emr-serverless-sg" })
}

resource "aws_emrserverless_application" "main" {
  count         = var.use_serverless ? 1 : 0
  name          = "${var.environment}-health-emr-serverless"
  release_label = "emr-6.15.0"
  type          = "spark"

  initial_capacity {
    initial_capacity_type = "Driver"
    initial_capacity_config {
      worker_count = 1
      worker_configuration {
        cpu    = "4 vCPU"
        memory = "16 GB"
      }
    }
  }

  initial_capacity {
    initial_capacity_type = "Executor"
    initial_capacity_config {
      worker_count = 2
      worker_configuration {
        cpu    = "4 vCPU"
        memory = "16 GB"
      }
    }
  }

  network_configuration {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.emr_serverless[0].id]
  }

  tags = merge(local.common_tags, { Name = "${var.environment}-emr-serverless" })
}

resource "aws_iam_role" "emr_serverless_role" {
  count = var.use_serverless ? 1 : 0
  name  = "${var.environment}-emr-serverless-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "emr-serverless.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = merge(local.common_tags, { Name = "${var.environment}-emr-serverless-role" })
}

resource "aws_iam_role_policy_attachment" "emr_serverless_s3" {
  count      = var.use_serverless ? 1 : 0
  role       = aws_iam_role.emr_serverless_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

output "cluster_id"          { value = length(aws_emr_cluster.main) > 0 ? aws_emr_cluster.main[0].id : "" }
output "cluster_arn"         { value = length(aws_emr_cluster.main) > 0 ? aws_emr_cluster.main[0].arn : "" }
output "serverless_app_id"   { value = length(aws_emrserverless_application.main) > 0 ? aws_emrserverless_application.main[0].id : "" }
output "serverless_role_arn" { value = length(aws_iam_role.emr_serverless_role) > 0 ? aws_iam_role.emr_serverless_role[0].arn : "" }
