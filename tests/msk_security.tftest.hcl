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

run "validate_open_monitoring" {
  command = plan

  variables {
    jmx_exporter_monitoring_enabled  = true
    node_exporter_monitoring_enabled = true
  }

  assert {
    condition     = aws_msk_cluster.msk_cluster.open_monitoring.prometheus.jmx_exporter.enabled_in_broker == true
    error_message = "MSK JMX Exporter monitoring is enabled"
  }

  assert {
    condition     = aws_msk_cluster.msk_cluster.open_monitoring.prometheus.node_exporter.enabled_in_broker == true
    error_message = "MSK Node Exporter monitoring is enabled"
  }
}

