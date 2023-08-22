resource "aws_db_subnet_group" "cloudacademy" {
  name       = "cloudacademy"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "CloudAcademy DB subnet group"
  }
}

resource "aws_security_group" "allow_mysql_from_private_subnets" {
  name   = "allow_mysql_from_private_subnets"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr_blocks
  }
}

resource "aws_rds_cluster" "cloudacademy" {
  cluster_identifier   = "cloudacademy"
  engine               = "aurora-mysql"
  engine_mode          = "serverless"
  enable_http_endpoint = true

  master_username = var.master_username
  master_password = var.master_password
  database_name   = var.db_name

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

resource "terraform_data" "db_setup" {
  triggers_replace = [
    filesha1("${path.module}/db_setup.sql")
  ]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    working_dir = path.module
    command     = <<-EOF
			while read line; do
				echo "$line"
				aws rds-data execute-statement --resource-arn "$DB_ARN" --database  "$DB_NAME" --secret-arn "$SECRET_ARN" --sql "$line"
			done  < <(awk 'BEGIN{RS=";\n"}{gsub(/\n/,""); if(NF>0) {print $0";"}}' db_setup.sql)
			EOF

    environment = {
      DB_ARN     = aws_rds_cluster.cloudacademy.arn
      DB_NAME    = var.db_name
      SECRET_ARN = var.secret_manager_arn
    }
  }
}
