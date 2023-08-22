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
      username = var.master_username
      password = var.master_password
      dbname   = var.db_name
      engine   = "mysql"
    }
  )
}
