resource "aws_security_group" "sg_msk" {
  name        = "${var.project_name}-${var.cluster_name}-${var.environment}-msk-sg"
  description = "Security group for ${var.project_name}-${var.cluster_name}-${var.environment}-msk"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  #Kafka Broker TLS port
  ingress {
    from_port   = 2182
    to_port     = 2182
    protocol    = "tcp"
    cidr_blocks = var.vpc_cidr
    description = "Security group Kafka ingress rule for ${var.project_name}-${var.cluster_name}-${var.environment}-msk"
  }

  #Zookeeper TLS port
  ingress {
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = var.vpc_cidr
    description = "Security group Zookeeper ingress rule for ${var.project_name}-${var.cluster_name}-${var.environment}-msk"
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "tcp"
    # Change this to your internal VPC CIDR or a specific monitoring IP. Egress should be restricted to internal VPC only
    cidr_blocks = var.vpc_cidr
    description = "Security group egress rule for ${var.project_name}-${var.cluster_name}-${var.environment}-msk"
  }
}


resource "aws_kms_key" "msk" {
  description             = "KMS key for MSK encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.common_tags
}

resource "aws_kms_key_policy" "msk_kms_policy" {
  key_id = aws_kms_key.msk.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "msk_kms_policy",
    "Statement" : [
      {
        "Sid" : "EnableIAMUserPermissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${var.account_id}:root"
        },
        "Action" : "kms:*",
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_kms_alias" "msk" {
  name          = "alias/${var.kms_alias}"
  target_key_id = aws_kms_key.msk.id
}
# CloudWatch Log Group for MSK
resource "aws_cloudwatch_log_group" "msk_broker_logs" {
  name              = "/aws/msk/${var.project_name}-${var.cluster_name}-${var.environment}-msk-broker"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.msk.id
  tags              = local.common_tags
}

# MSK Cluster
resource "aws_msk_cluster" "msk_cluster" {
  cluster_name           = "${var.project_name}-${var.cluster_name}-${var.environment}-msk"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes



  broker_node_group_info {
    instance_type   = var.instance_type
    client_subnets  = var.subnet_ids
    security_groups = [aws_security_group.sg_msk.id]
    storage_info {
      ebs_storage_info {
        volume_size = var.ebs_volume_size
      }
    }
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = var.jmx_exporter_monitoring_enabled
      }
      node_exporter {
        enabled_in_broker = var.node_exporter_monitoring_enabled
      }
    }
  }

  storage_mode = var.storage_mode

  client_authentication {
    dynamic "tls" {
      for_each = var.iam_authentication ? [] : [1]
      content {
        certificate_authority_arns = length(var.ca_arn) != 0 ? var.ca_arn : [aws_acmpca_certificate_authority.msk_kafka_with_ca[count.index].arn]
      }
    }
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.msk.arn
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk_broker_logs.name
      }
      s3 {
        enabled = true
        bucket  = aws_s3_bucket.msk_logs.id
        prefix  = "logs/msk-"
      }
    }
  }

  tags = local.common_tags
}

## Logging s3 bucket

resource "aws_s3_bucket" "msk_logs" {
  bucket = "${var.project_name}-${var.cluster_name}-${var.environment}-logs"
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "logs_access" {
  bucket = aws_s3_bucket.msk_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "msk_logs_versioning" {
  bucket = aws_s3_bucket.msk_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "msk_logs" {
  bucket = aws_s3_bucket.msk_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.msk.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "msk_logs" {
  bucket = aws_s3_bucket.msk_logs.id

  rule {
    id     = "cc-bucket-lifecycle-rule-msk-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = var.lifecycle_expiration_days
    }
  }

  rule {
    id     = "cc-abort-incomplete-multipart-uploads-msk-logs"
    status = "Enabled"

    # No filter → applies to all multipart uploads
    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.days_after_initiation
    }
  }
}

## MSK Scaling

resource "aws_appautoscaling_target" "msk_appautoscaling_target" {
  count = var.storage_autoscaling_max_capacity > var.ebs_volume_size ? 1 : 0
  tags  = local.common_tags

  max_capacity       = var.storage_autoscaling_max_capacity
  min_capacity       = 1
  resource_id        = aws_msk_cluster.msk_cluster.arn
  scalable_dimension = "kafka:broker-storage:VolumeSize"
  service_namespace  = "kafka"
}

resource "aws_appautoscaling_policy" "msk_appautoscaling_policy" {
  count = var.storage_autoscaling_max_capacity > var.ebs_volume_size ? 1 : 0

  name               = "${var.project_name}-${var.cluster_name}-${var.environment}-msk-broker-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_msk_cluster.msk_cluster.arn
  scalable_dimension = join("", aws_appautoscaling_target.msk_appautoscaling_target[*].scalable_dimension)
  service_namespace  = join("", aws_appautoscaling_target.msk_appautoscaling_target[*].service_namespace)

  target_tracking_scaling_policy_configuration {
    # Can't scale down an msk cluster disk after increasing it.
    disable_scale_in = "true"
    predefined_metric_specification {
      predefined_metric_type = "KafkaBrokerStorageUtilization"
    }

    target_value = var.storage_autoscaling_threshold
  }
}

## Certificate Authority
resource "aws_acmpca_certificate_authority" "msk_with_ca" {

  count = var.certificate_authority == "true" ? 1 : 0
  tags  = local.common_tags

  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"

    subject {
      common_name = "${var.cluster_name}-ca"
    }
  }

  type                            = var.ca_type
  permanent_deletion_time_in_days = 7

}

resource "aws_iam_user" "msk_acmpca_iam_user" {
  count = var.certificate_authority == "true" ? 1 : 0
  name  = "${var.cluster_name}-acmpca-user"
  path  = "/"
  tags  = local.common_tags
}

#policy attachment for CA policy
resource "aws_iam_policy" "acmpca_policy_with_msk_policy" {
  count  = var.certificate_authority == "true" ? 1 : 0
  name   = "${var.cluster_name}-acmpcaPolicy"
  tags   = local.common_tags
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "IAMacmpcaPermissions",
      "Effect": "Allow",
      "Action": [
        "acm-pca:IssueCertificate",
        "acm-pca:GetCertificate"
      ],
      "Resource": "${aws_msk_cluster.msk_cluster.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "msk_acmpca_iam_policy_attachment" {
  count      = var.certificate_authority == "true" ? 1 : 0
  name       = "${var.cluster_name}-acmpca-policy-attachment"
  users      = [aws_iam_user.msk_acmpca_iam_user[count.index].name]
  policy_arn = aws_iam_policy.acmpca_policy_with_msk_policy[count.index].arn
}

resource "aws_iam_user" "msk_iam_user" {
  name = "${var.cluster_name}-user"
  path = "/"
  tags = local.common_tags
}

resource "aws_iam_policy" "msk_iam_policy" {
  name   = "${var.cluster_name}-policy"
  tags   = local.common_tags
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "IAMPermissions",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricStatistics"
      ],
      "Resource": "${aws_msk_cluster.msk_cluster.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "msk_iam_policy_attachment" {
  name       = "${var.cluster_name}-policy-attachment"
  users      = [aws_iam_user.msk_iam_user.name]
  policy_arn = aws_iam_policy.msk_iam_policy.arn
}

resource "aws_iam_policy" "msk_iam_authentication" {
  tags        = local.common_tags
  name        = "${var.cluster_name}-iam-auth-policy"
  description = "This policy allow IAM authenticated user to connect to MSK"
  policy      = aws_iam_policy.acmpca_policy_with_msk_policy[count.index].policy
}


resource "aws_iam_policy_attachment" "msk_iam_authentication_policy" {
  name       = "${var.cluster_name}-authentication-policy-attachment"
  users      = [aws_iam_user.msk_iam_user.name]
  policy_arn = aws_iam_policy.msk_iam_authentication[count.index].arn
}


locals {
  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    },
    var.tags
  )
}