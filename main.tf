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
      },
      {
        Sid    = "Allow Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*",
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.region}:${var.account_id}:log-group:*"
          }
        }
      },
      {
        Sid    = "AllowMSKRoleDecrypt",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.msk_role.arn
        },
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ],
        Resource = ["arn:aws:kms:${var.region}:${var.account_id}:key/*}"]
      }
    ]
  })
}

resource "aws_kms_alias" "msk" {
  name          = "alias/${var.kms_alias}"
  target_key_id = aws_kms_key.msk.id
}

resource "aws_iam_role" "msk_role" {
  name = "${var.cluster_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "kafka.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "msk_cloudwatch_logs_write" {
  name        = "${var.cluster_name}-cloudwatch-logs"
  description = "Allow MSK logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = [
          "${aws_cloudwatch_log_group.msk_broker_logs.arn}/*",
          "arn:aws:logs:${var.region}:${var.account_id}:log-group:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_cloudwatch_logs" {
  role       = aws_iam_role.msk_role.name
  policy_arn = aws_iam_policy.msk_cloudwatch_logs_write.arn
}

resource "aws_iam_policy" "msk_permissions" {
  name        = "${var.cluster_name}-permissions"
  description = "Allow Kafka and KMS permissions"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:CreateGrant",
          "kafka-cluster:*",
          "kafka:*"
        ],
        Resource = ["arn:aws:kafka:${var.region}:${var.account_id}:cluster/*", "arn:aws:kafka:${var.region}:${var.account_id}:topic/*"]
      },
      {
        Effect = "Allow",
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeCluster"
        ],
        Resource = ["arn:aws:kafka:${var.region}:${var.account_id}:cluster/*"]
      },
      {
        Effect = "Allow",
        Action = [
          "kafka-cluster:*Topic*",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData"
        ],
        Resource = ["arn:aws:kafka:${var.region}:${var.account_id}:topic/*"]
      },
      {
        Effect = "Allow",
        Action = [
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ],
        "Resource" : ["arn:aws:kafka:${var.region}:${var.account_id}:group/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_msk_permissions" {
  role       = aws_iam_role.msk_role.name
  policy_arn = aws_iam_policy.msk_permissions.arn
}

# CloudWatch Log Group for MSK
resource "aws_cloudwatch_log_group" "msk_broker_logs" {
  name              = "/aws/msk/${var.project_name}-${var.cluster_name}-${var.environment}-msk-broker"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.msk.arn
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
      for_each = var.tls_authentication ? [] : [1]
      content {
        certificate_authority_arns = var.ca_arn
      }
    }
    unauthenticated = var.client_unauthenticated
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
    }
  }

  tags = local.common_tags
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
  count = var.certificate_authority == true ? 1 : 0
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

data "aws_iam_policy_document" "msk_ca_policy" {
  statement {
    effect = "Allow"

    actions = [
      "acm-pca:IssueCertificate",
      "acm-pca:GetCertificate",
    ]
    resources = [aws_msk_cluster.msk_cluster.arn]
  }
}

resource "aws_iam_policy" "msk_iam_ca_policy" {
  name   = "${var.cluster_name}-acmpca-policy"
  policy = data.aws_iam_policy_document.msk_ca_policy.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "msk_ca_policy_attachment" {
  count      = var.certificate_authority == true ? 1 : 0
  role       = aws_iam_role.msk_role.name
  policy_arn = aws_iam_policy.msk_iam_ca_policy.arn
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