terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10.0"
    }
  }
}

locals {
  region = "ap-south-1"
}

provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

locals {
  name        = "cloudacademydevops"
  environment = "prod"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)
  # returns
  #   tolist([
  #   "us-west-2a",
  #   "us-west-2b"
  # ])

  k8s = {
    stocks_app_architecture = "arch1" # <===== either arch1 or arch2

    cluster_name   = "${local.name}-eks-${local.environment}"
    version        = "1.27"
    #instance_types = ["m5.large"]
    instance_types = ["t2.medium"]
    capacity_type  = "ON_DEMAND"
    disk_size      = 10
    min_size       = 2
    max_size       = 2
    desired_size   = 2
  }

  rds = {
    master_username = "root"
    master_password = "followthewhiterabbit"
    db_name         = "cloudacademy"
    scaling_min     = 2
    scaling_max     = 4
  }
}

#====================================

module "secretsmanager" {
  source          = "./modules/secretsmanager"
  master_username = local.rds.master_username
  master_password = local.rds.master_password
  db_name         = local.rds.db_name
}

#====================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 5.0.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  manage_default_network_acl    = true
  manage_default_route_table    = true
  manage_default_security_group = true

  default_network_acl_tags = {
    Name = "${local.name}-default"
  }

  default_route_table_tags = {
    Name = "${local.name}-default"
  }

  default_security_group_tags = {
    Name = "${local.name}-default"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Name        = "${local.name}-eks"
    Environment = local.environment
  }
}

#====================================

module "aurora" {
  source              = "./modules/aurora"
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnets
  ingress_cidr_blocks = module.vpc.private_subnets_cidr_blocks
  master_username     = local.rds.master_username
  master_password     = local.rds.master_password
  db_name             = local.rds.db_name
  secret_manager_arn  = module.secretsmanager.arn
}

#====================================

module "eks" {
  # forked from terraform-aws-modules/eks/aws, fixes deprecated resolve_conflicts issue
  source = "github.com/cloudacademy/terraform-aws-eks"

  cluster_name    = local.k8s.cluster_name
  cluster_version = local.k8s.version

  cluster_endpoint_public_access   = true
  attach_cluster_encryption_policy = false
  create_iam_role                  = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      use_custom_launch_template = false
      create_iam_role            = true

      instance_types = local.k8s.instance_types
      capacity_type  = local.k8s.capacity_type

      disk_size = local.k8s.disk_size

      min_size     = local.k8s.min_size
      max_size     = local.k8s.max_size
      desired_size = local.k8s.desired_size
    }
  }

  //don't do in production - this is for demo/lab purposes only
  create_kms_key            = false
  cluster_encryption_config = {}

  tags = {
    Name        = "${local.name}-eks"
    Environment = local.environment
  }
}

#====================================

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", local.region]
    }
  }
}

resource "helm_release" "nginx_ingress" {
  name = "nginx-ingress"

  repository       = "https://helm.nginx.com/stable"
  chart            = "nginx-ingress"
  namespace        = "nginx-ingress"
  create_namespace = true

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "controller.service.name"
    value = "nginx-ingress-controller"
  }

  depends_on = [
    module.eks
  ]
}

resource "terraform_data" "deploy_app" {
  triggers_replace = [
    "${timestamp()}"
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = "${path.module}/k8s/archs/${local.k8s.stocks_app_architecture}"
    command     = <<EOT
      echo "setting up k8s auth..."
      aws eks update-kubeconfig --region ${local.region} --name ${module.eks.cluster_name}
      echo "deploying *** ${local.k8s.stocks_app_architecture} *** pattern..."
      rm -f ./manifests/*.yaml
      tree
      ./app.install.sh ${module.aurora.db_endpoint}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete ns cloudacademy --force=true"
  }

  depends_on = [
    module.aurora,
    module.eks,
    helm_release.nginx_ingress
  ]
}
