output "zookeeper_connect_string" {
  value     = aws_msk_cluster.msk_cluster.zookeeper_connect_string
  sensitive = true
}

output "bootstrap_brokers_tls" {
  value     = aws_msk_cluster.msk_cluster.bootstrap_brokers_tls
  sensitive = true
}

output "msk_cluster_arn" {
  description = "The MSK cluster arn"
  value       = aws_msk_cluster.msk_cluster.arn
  sensitive   = true
}

output "msk_sg_id" {
  description = "The MSK security group ID"
  value       = aws_security_group.sg_msk.id
  sensitive   = true
}