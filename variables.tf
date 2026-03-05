variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "vpc_id" {
  description = "The MSK cluster's VPC ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the MSK Cluster"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "MSK Cluster Instance Type"
  type        = string
  default     = "kafka.t3.small"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = ""
}

variable "kms_alias" {
  description = "KMS key alias for bucket encryption"
  type        = string
  nullable    = false
}

variable "vpc_cidr" {
  description = "VPC CIDR Range"
  type        = list(string)
}

variable "tags" {
  description = "Tags to be applied to the bucket"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      contains(keys(var.tags), "account-code"),
      contains(keys(var.tags), "cost-centre"),
      contains(keys(var.tags), "portfolio-id"),
      contains(keys(var.tags), "project-id"),
      contains(keys(var.tags), "service-id"),
      contains(keys(var.tags), "environment-type"),
      contains(keys(var.tags), "owner-business"),
      contains(keys(var.tags), "budget-holder"),
      contains(keys(var.tags), "source-repo")
    ])
    error_message = "Tags must include all mandatory fields."
  }
}

variable "account_id" {
  description = "The AWS Account ID."
  type        = string
}

variable "kafka_version" {
  type    = string
  default = "3.9.x"
}

variable "number_of_broker_nodes" {
  type    = number
  default = 3
}

variable "ebs_volume_size" {
  description = "MSK EBS Volume Size"
  type        = number
  default     = 1000
}

variable "subnet_ids" {
  description = "A list of subnets that the MSK cluster should run in"
  type        = list(string)
}

variable "jmx_exporter_monitoring_enabled" {
  description = "Whether to enable JMX Exporter Open Monitoring"
  type        = bool
  default     = false
}

variable "node_exporter_monitoring_enabled" {
  description = "Whether to enable Node Exporter Open Monitoring"
  type        = bool
  default     = false
}

variable "storage_mode" {
  description = "Specify the storage mode for MSK brokers. Valid values: LOCAL (default) or TIERED."
  type        = string
  default     = "LOCAL"
}

variable "lifecycle_expiration_days" {
  description = "Number of days to keep s3 objects before expiration"
  type        = number
  default     = 30
}

variable "days_after_initiation" {
  description = "Specifies the number of days after initiating a multipart upload when the multipart upload must be completed."
  default     = 15
  type        = number
}

variable "storage_autoscaling_max_capacity" {
  description = "The MSK cluster EBS maximum volume size for each broker. Value between 1 and 16384."
  type        = number
  default     = 1
  validation {
    condition = (
      var.storage_autoscaling_max_capacity >= 1 &&
      var.storage_autoscaling_max_capacity <= 16384
    )
    error_message = "Storage autoscaling max capacity must be between 1 and 16384."
  }
}

variable "storage_autoscaling_threshold" {
  description = "The percentage threshold that needs to be exceeded to trigger a scale up. Value between 10 and 80."
  type        = number
  default     = 65
  validation {
    condition = (
      var.storage_autoscaling_threshold >= 10 &&
      var.storage_autoscaling_threshold <= 80
    )
    error_message = "Storage autoscaling threshold must be between 10 and 80."
  }
}

variable "certificate_authority" {
  description = "True if PCA should be created on cluster creation and there is not an existing CA to use"
  type        = bool
  default     = null
}

variable "ca_type" {
  description = "The type of the certificate authority"
  type        = string
  default     = "SUBORDINATE"
}

variable "ca_arn" {
  description = "ARN of the AWS managed CA to attach to the MSK cluster"
  default     = []
  type        = list(string)
}

variable "iam_authentication" {
  description = "Enables IAM client authentication"
  type        = bool
  default     = false
}