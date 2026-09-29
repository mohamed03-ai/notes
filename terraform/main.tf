terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "notes-eks"
}

# EKS does not support every AZ (for example us-east-1e), so list allowed ones
variable "azs" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

provider "aws" {
  region = var.region
}

# The pre-made lab role (you cannot create IAM roles in Learner Lab)
data "aws_iam_role" "lab" {
  name = "LabRole"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = var.azs
  }
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = data.aws_iam_role.lab.arn

  vpc_config {
    subnet_ids = data.aws_subnets.default.ids
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "notes-nodes"
  node_role_arn   = data.aws_iam_role.lab.arn
  subnet_ids      = data.aws_subnets.default.ids
  instance_types  = ["t3.medium"]
  disk_size       = 20

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 3
  }
}

# Lets the Jenkins EC2 instance (which uses LabRole) reach the cluster
resource "aws_eks_access_entry" "lab_role" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = data.aws_iam_role.lab.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "lab_role_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = data.aws_iam_role.lab.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.lab_role]
}

output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.this.name}"
}
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"

  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
  })

  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.this]
}