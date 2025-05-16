variable "aws_region" {
  description = "AWS region for the EKS cluster"
  type        = string
  default     = "us-east-1" # Change this to your desired region
}

variable "cluster_name" {
  description = "Name for the EKS cluster"
  type        = string
  default     = "my-dev-eks-cluster" # Choose a unique name
}

variable "eks_version" {
  description = "Desired Kubernetes version for EKS cluster"
  type        = string
  default     = "1.29" # Check AWS documentation for supported versions
}

variable "node_instance_type" {
  description = "EC2 instance type for the EKS worker nodes"
  type        = string
  default     = "t3.medium" # Choose an appropriate instance type
}

variable "desired_node_count" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

provider "aws" {
  region = var.aws_region
}
