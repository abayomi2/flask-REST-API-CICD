# --- Outputs ---
output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.eks_cluster.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded certificate data required to communicate with the cluster."
  value       = aws_eks_cluster.eks_cluster.certificate_authority[0].data
  sensitive   = true
}

output "eks_nodegroup_role_arn" {
  description = "ARN of the EKS Node Group IAM role."
  value       = aws_iam_role.eks_nodegroup_role.arn
}

output "default_vpc_id" {
  description = "ID of the default VPC used."
  value       = data.aws_vpc.default.id
}

output "filtered_subnet_ids_for_eks" {
  description = "List of subnet IDs from the default VPC in supported AZs, used for the EKS cluster and nodes."
  value       = data.aws_subnets.default_vpc_subnets_in_supported_azs.ids
}

output "number_of_filtered_subnets" {
  description = "Number of subnets found in supported AZs."
  value       = length(data.aws_subnets.default_vpc_subnets_in_supported_azs.ids)
}