terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Specify a version constraint for the AWS provider
    }
  }
}

# --- 1. Data Sources to use Default VPC and Filtered Subnets ---
data "aws_vpc" "default" {
  default = true
}

# Define the list of supported AZs for EKS Control Plane in us-east-1
# Based on the error message: us-east-1a, us-east-1b, us-east-1c, us-east-1d, us-east-1f
# IMPORTANT: If you change the `aws_region` variable, you MUST verify and update this list
# for the new region based on AWS documentation or any new errors encountered.
locals {
  supported_eks_control_plane_azs_us_east_1 = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
}

data "aws_subnets" "default_vpc_subnets_in_supported_azs" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = local.supported_eks_control_plane_azs_us_east_1 # Use the defined list
  }
}

# --- 2. IAM Role for EKS Cluster ---
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}

# --- 3. IAM Role for EKS Node Group ---
resource "aws_iam_role" "eks_nodegroup_role" {
  name = "${var.cluster_name}-nodegroup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-nodegroup-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_nodegroup_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodegroup_role.name
}

resource "aws_iam_role_policy_attachment" "eks_nodegroup_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodegroup_role.name
}

resource "aws_iam_role_policy_attachment" "eks_nodegroup_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodegroup_role.name
}

# --- 4. EKS Cluster ---
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.eks_version

  vpc_config {
    # Use the SUBNET IDs that are in the SUPPORTED Availability Zones
    subnet_ids = data.aws_subnets.default_vpc_subnets_in_supported_azs.ids

    # Check: EKS requires at least two subnets in different supported AZs for the control plane.
    # This check will fail 'terraform plan' or 'apply' if not met.
    # Note: The aws_eks_cluster resource itself will perform this validation during apply.
    # Adding a precondition here offers an earlier check.
    # However, accurately checking unique AZs for the selected subnets within Terraform's
    # language can be complex. For now, we rely on AWS EKS to validate this during apply.
    # If 'terraform apply' still fails with an AZ related error for the control plane,
    # ensure 'data.aws_subnets.default_vpc_subnets_in_supported_azs.ids' resolves to
    # subnets in at least two *different* AZs from the 'local.supported_eks_control_plane_azs_us_east_1' list.
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSVPCResourceController,
  ]

  tags = {
    Name = var.cluster_name
  }

  lifecycle {
    # Precondition to ensure we have found at least two subnets in supported AZs.
    # EKS control plane requires subnets in at least two Availability Zones.
    precondition {
      condition     = length(data.aws_subnets.default_vpc_subnets_in_supported_azs.ids) >= 2
      error_message = "At least two subnets in the supported Availability Zones must be found in the default VPC. Found ${length(data.aws_subnets.default_vpc_subnets_in_supported_azs.ids)} subnets. Please check your default VPC configuration and the list of supported AZs for EKS in region ${var.aws_region}."
    }
  }
}

# --- 5. EKS Managed Node Group ---
resource "aws_eks_node_group" "eks_nodegroup" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.cluster_name}-default-nodes"
  node_role_arn   = aws_iam_role.eks_nodegroup_role.arn
  # Node groups can often use a wider range of AZs than the control plane.
  # However, for simplicity and to ensure they are in the same VPC and can communicate easily
  # with the control plane, we'll use the same filtered list of subnets.
  # If you needed nodes in other AZs (like us-east-1e), you'd fetch those subnets separately
  # and ensure proper routing and security group configurations.
  subnet_ids      = data.aws_subnets.default_vpc_subnets_in_supported_azs.ids

  instance_types = [var.node_instance_type]
  disk_size      = 20 # GiB

  scaling_config {
    desired_size = var.desired_node_count
    min_size     = var.min_node_count
    max_size     = var.max_node_count
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_nodegroup_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_nodegroup_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.eks_nodegroup_AmazonEKS_CNI_Policy,
    aws_eks_cluster.eks_cluster,
  ]

  tags = {
    Name = "${var.cluster_name}-nodegroup"
  }
}
