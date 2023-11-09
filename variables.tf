variable "region" {
  default = "eu-north-1"
}

variable "vpc_cidr" {
  default = "10.1.0.0/16"
}

variable "subnet_cidr" {
  default = "10.1.1.0/24"
}

variable "path_for_ansible" {
  default = "ansible/"
}

variable "tag" {
  type = map(string)
  default = {
    kubernetes = "owned",
    ManagedBy  = "Terraform"
  }
}

variable "my_name" {
  default = "k8s"
}

variable "port" {
  type    = list(any)
  default = ["0"]
}

variable "numbers_instans_workers_deploy" {
  default = 1
}

variable "instance_type_master_deploy" {
  default = "t3.small"
}

variable "instance_type_worker_deploy" {
  default = "t3.micro"
}

variable "user" {
  default = {
    al20 = "ec2-user"
    ubun = "ubuntu"
    RHEL = "ec2-user"
    suse = "ec2-user"
    debi = "admin"
  }
}

variable "domain" {
  default = "fatherfedor.shop"
}

variable "aws_user_id" {
  default = 728490037630
}

variable "number_replicas" {
  default = 2
}