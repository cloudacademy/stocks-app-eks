variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "ingress_cidr_blocks" {
  type = list(string)
}

variable "master_username" {
  type = string
}

variable "master_password" {
  type = string
}

variable "db_name" {
  type = string
}

variable "engine" {
  type = string
}

variable "engine_version" {
  type = string
}

variable "secret_manager_arn" {
  type = string
}

variable "acu_min" {
  type = number
}

variable "acu_max" {
  type = number
}
