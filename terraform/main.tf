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

provider "aws" {
  region = "us-west-2"
}

data "aws_availability_zones" "available" {}

locals {
  name        = "cloudacademydevops"
  environment = "demo"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  k8s = {
    version        = "1.27"
    instance_types = ["m5.large"]
    capacity_type  = "SPOT"
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

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = ">= 19.15.0"

  cluster_name    = "${local.name}-eks"
  cluster_version = local.k8s.version

  cluster_endpoint_public_access = true

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

      instance_types = local.k8s.instance_types
      capacity_type  = local.k8s.capacity_type

      disk_size = local.k8s.disk_size

      min_size     = local.k8s.min_size
      max_size     = local.k8s.max_size
      desired_size = local.k8s.desired_size
    }
  }

  tags = {
    Name        = "${local.name}-eks"
    Environment = local.environment
  }
}

#====================================

resource "aws_db_subnet_group" "cloudacademy" {
  name       = "cloudacademy"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "CloudAcademy DB subnet group"
  }
}

resource "aws_security_group" "allow_mysql_from_private_subnets" {
  name   = "allow_mysql_from_private_subnets"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }
}

resource "aws_rds_cluster" "cloudacademy" {
  cluster_identifier   = "cloudacademy"
  engine               = "aurora-mysql"
  engine_mode          = "serverless"
  enable_http_endpoint = true

  master_username = local.rds.master_username
  master_password = local.rds.master_password
  database_name   = local.rds.db_name

  backup_retention_period = 1
  skip_final_snapshot     = true
  db_subnet_group_name    = aws_db_subnet_group.cloudacademy.name
  vpc_security_group_ids  = [aws_security_group.allow_mysql_from_private_subnets.id]

  scaling_configuration {
    auto_pause               = true
    min_capacity             = 1
    max_capacity             = 1
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }
}

#====================================

resource "random_id" "db_creds" {
  byte_length = 8
}

resource "aws_secretsmanager_secret" "db_creds" {
  name = "db-creds-${random_id.db_creds.hex}"
}

resource "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode(
    {
      username = local.rds.master_username
      password = local.rds.master_password
      dbname   = local.rds.db_name
      engine   = "mysql"
    }
  )
}

resource "terraform_data" "db_setup" {
  triggers_replace = [
    filesha1("db_setup.sql")
  ]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOF
			while read line; do
				echo "$line"
				aws rds-data execute-statement --resource-arn "$DB_ARN" --database  "$DB_NAME" --secret-arn "$SECRET_ARN" --sql "$line"
			done  < <(awk 'BEGIN{RS=";\n"}{gsub(/\n/,""); if(NF>0) {print $0";"}}' db_setup.sql)
			EOF

    environment = {
      DB_ARN     = aws_rds_cluster.cloudacademy.arn
      DB_NAME    = local.rds.db_name
      SECRET_ARN = aws_secretsmanager_secret.db_creds.arn
    }
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
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
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
}

resource "terraform_data" "deploy_app" {
  triggers_replace = [
    "${timestamp()}"
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    working_dir = path.module
    command     = <<EOT
      echo deploying app...
      ./k8s/app.install.sh ${aws_rds_cluster.cloudacademy.endpoint}
    EOT
  }

  depends_on = [
    helm_release.nginx_ingress,
    terraform_data.db_setup
  ]
}
