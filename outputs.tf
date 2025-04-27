output "jenkins_public_ip" {
  description = "Jenkins EC2 Public IP"
  value       = aws_instance.jenkins.public_ip
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_node_group_role_arn" {
  value = module.eks.eks_managed_node_groups["node_group"].iam_role_arn
}
