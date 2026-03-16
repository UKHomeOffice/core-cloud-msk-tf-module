// Mock provider to avoid real AWS/random calls during tests.
mock_provider "aws" {}

variables {

  account_id                       = "100000000000"
  certificate_authority            = true
  client_unauthenticated           = false
  cluster_name                     = "msk-test"
  ebs_volume_size                  = 1000
  environment                      = "test"
  instance_type                    = "kafka.t3.small"
  jmx_exporter_monitoring_enabled  = true
  node_exporter_monitoring_enabled = true
  number_of_broker_nodes           = 2
  project_name                     = "testproject"
  storage_autoscaling_max_capacity = 1050
  subnet_ids                       = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]
  tls_authentication               = true
  vpc_id                           = "vpc-00000000000000000"
  vpc_cidr                         = ["10.0.0.0/8"]

  tags = {
    Environment      = "test"
    Project          = "test"
    cost-centre      = "CC1000"
    account-code     = "AC1000"
    portfolio-id     = "PF1000"
    project-id       = "PR1000"
    service-id       = "SV1000"
    environment-type = "test"
    owner-business   = "test"
    budget-holder    = "testteam"
    source-repo      = "UKHomeOffice/core-cloud-msk-tf-module"
  }
}

run "validate_required_tags_on_msk" {
  command = plan

  assert {
    condition     = contains(keys(aws_msk_cluster.msk_cluster.tags), "cost-centre")
    error_message = "cost-centre tag must be present on MSK instance"
  }

  assert {
    condition     = contains(keys(aws_msk_cluster.msk_cluster.tags), "account-code")
    error_message = "account-code tag must be present on MSK instance"
  }

  assert {
    condition     = contains(keys(aws_msk_cluster.msk_cluster.tags), "portfolio-id")
    error_message = "portfolio-id tag must be present on MSK instance"
  }

  assert {
    condition     = contains(keys(aws_msk_cluster.msk_cluster.tags), "project-id")
    error_message = "project-id tag must be present on MSK instance"
  }

  assert {
    condition     = contains(keys(aws_msk_cluster.msk_cluster.tags), "service-id")
    error_message = "service-id tag must be present on MSK instance"
  }

  assert {
    condition     = contains(keys(aws_msk_cluster.msk_cluster.tags), "environment-type")
    error_message = "environment-type tag must be present on MSK instance"
  }

  assert {
    condition     = contains(keys(aws_msk_cluster.msk_cluster.tags), "owner-business")
    error_message = "owner-business tag must be present on MSK instance"
  }

  assert {
    condition     = contains(keys(aws_msk_cluster.msk_cluster.tags), "budget-holder")
    error_message = "budget-holder tag must be present on MSK instance"
  }

  assert {
    condition     = contains(keys(aws_msk_cluster.msk_cluster.tags), "source-repo")
    error_message = "source-repo tag must be present on MSK instance"
  }
}

run "validate_tag_values" {
  command = plan

  variables {
    environment  = "test"
    project_name = "test"
  }

  assert {
    condition     = aws_msk_cluster.msk_cluster.tags["Environment"] == "test"
    error_message = "Environment tag must match the environment variable"
  }

  assert {
    condition     = aws_msk_cluster.msk_cluster.tags["Project"] == "test"
    error_message = "Project tag must match the project_name variable"
  }

  assert {
    condition     = aws_msk_cluster.msk_cluster.tags["ManagedBy"] == "terraform"
    error_message = "ManagedBy tag must be set to 'terraform'"
  }
}

run "validate_additional_tags_merged" {
  command = plan

  variables {
    tags = {
      Environment      = "test"
      Project          = "test"
      cost-centre      = "CC1000"
      account-code     = "AC1000"
      portfolio-id     = "PF1000"
      project-id       = "PR1000"
      service-id       = "SV1000"
      environment-type = "test"
      owner-business   = "test"
      budget-holder    = "testteam"
      source-repo      = "UKHomeOffice/core-cloud-msk-tf-module"
      CustomTag        = "CustomValue"
    }
  }

  # Verify additional tags from var.tags are merged
  assert {
    condition     = aws_msk_cluster.msk_cluster.tags["cost-centre"] == "CC1000"
    error_message = "Additional tags from var.tags must be merged into MSK tags"
  }

  assert {
    condition     = can(aws_msk_cluster.msk_cluster.tags["CustomTag"])
    error_message = "Custom tags from var.tags must be present on MSK cluster"
  }

  assert {
    condition     = contains(["test"], aws_msk_cluster.msk_cluster.tags["Environment"])
    error_message = "Environment tag should be: test"
  }
}

