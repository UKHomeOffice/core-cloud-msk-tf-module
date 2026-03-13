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

run "validate_msk_creation" {
  command = plan

  assert {
    condition     = aws_msk_cluster.msk_cluster.msk == "testproject-testmsk-test-msk"
    error_message = "MSK name should follow pattern: {project_name}-{cluster_name}-{environment}-msk"
  }

  assert {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", aws_msk_cluster.msk_cluster.msk))
    error_message = "MSK name must follow AWS naming conventions (lowercase, numbers, hyphens)"
  }
}