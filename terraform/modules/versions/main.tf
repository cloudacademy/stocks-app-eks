terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.100.0, < 6.0.0"
    }
  }
}

data "aws_eks_cluster_versions" "standard" {
  cluster_type   = "eks"
  version_status = "STANDARD_SUPPORT"

  lifecycle {
    postcondition {
      condition     = length(self.cluster_versions) > 0
      error_message = "No EKS versions in standard support are available in this region."
    }
  }
}

locals {
  # Zero-padded numeric keys keep 1.100 after 1.99 when Terraform sorts strings.
  eks_versions = {
    for version in data.aws_eks_cluster_versions.standard.cluster_versions :
    format("%05d.%05d", tonumber(split(".", version.cluster_version)[0]), tonumber(split(".", version.cluster_version)[1])) => version.cluster_version
  }
}

data "aws_rds_engine_version" "aurora" {
  engine                 = "aurora-mysql"
  parameter_group_family = "aurora-mysql8.0"
  latest                 = true
  include_all            = false
}

# Fail at planning if the selected release cannot run on Serverless v2 here.
data "aws_rds_orderable_db_instance" "aurora" {
  engine                     = "aurora-mysql"
  engine_version             = data.aws_rds_engine_version.aurora.version_actual
  preferred_instance_classes = ["db.serverless"]
  supported_engine_modes     = ["provisioned"]
}

output "eks_version" {
  description = "Oldest EKS Kubernetes minor version currently in standard support."
  value       = try(values(local.eks_versions)[0], null)
}

output "aurora_version" {
  description = "Latest available MySQL 8.0-compatible Aurora version, verified for Serverless v2."
  value       = data.aws_rds_orderable_db_instance.aurora.engine_version
}
