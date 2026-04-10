variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "biteco-escalabilidad"
}

variable "key_name" {
  description = "Nombre del Key Pair EC2 de tu cuenta AWS"
}

variable "app_port" {
  default = 8000
}

variable "db_name" {
  default = "bitecodb"
}

variable "db_username" {
  default = "biteco"
}

variable "db_password" {
  sensitive = true
  default   = "BitEco2024Pw"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "asg_min_size" {
  default = 3
}

variable "asg_desired_capacity" {
  default = 3
}

variable "asg_max_size" {
  default = 8
}
