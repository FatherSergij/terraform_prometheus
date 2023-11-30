provider "aws" {
  region = var.region
  default_tags {
    tags = var.tag
  }
}

module "aws_vpc_create" {
  source      = "./modules/aws_vpc_create"
  my_name     = var.my_name
  vpc_cidr    = var.vpc_cidr
  subnet_cidr = var.subnet_cidr
}

module "deploy_instances" {
  source               = "./modules/deploy_instances"
  vpc_id               = module.aws_vpc_create.vpc_id
  subnet_id            = module.aws_vpc_create.subnet_id
  nm_worker            = var.numbers_instans_workers_deploy
  my_name              = var.my_name
  port                 = var.port
  instance_type_master = var.instance_type_master_deploy
  instance_type_worker = var.instance_type_worker_deploy
  path_for_ansible     = var.path_for_ansible
}

locals {
  user_name = var.user[substr(module.deploy_instances.user_from_ami, 0, 4)] //Can do it as below
  //user_name = lookup(var.user, substr(module.deploy_instances.user_from_ami, 0, 4))  
}

module "create_files" {
  source           = "./modules/create_files"
  path_for_ansible = var.path_for_ansible
  master_ip        = module.deploy_instances.master_ip
  workers_ip       = module.deploy_instances.workers_ip.*
  key_name         = module.deploy_instances.key_name
  user             = local.user_name
}

resource "null_resource" "instance_deploy" {
  triggers = {
    timestamp = timestamp() //for ansible-playbook to to run always
  }

  provisioner "remote-exec" {
    inline = ["hostname"]
    connection {
      host        = module.deploy_instances.master_ip //so that the master is created
      type        = "ssh"
      user        = local.user_name
      private_key = file(module.deploy_instances.path_key_file)
    }
  }

  provisioner "remote-exec" {
    inline = ["hostname"]
    connection {
      host        = element(module.deploy_instances.workers_ip, length(module.deploy_instances.workers_ip) - 1) //so that the last worker is created
      type        = "ssh"
      user        = local.user_name
      private_key = file(module.deploy_instances.path_key_file)
    }
  }

  provisioner "local-exec" {
    command = "cd ansible/ && ansible-playbook -e 'region_from_terraform'=${var.region} -e 'domain_from_terraform'=${var.domain} -e 'aws_user_id_from_terraform'=${var.aws_user_id} -e 'number_replicas_from_terraform'=${var.number_replicas_web} main.yml"
  } 
}

resource "null_resource" "output_adresses" {
  depends_on = [null_resource.instance_deploy]
  triggers = {
    timestamp = timestamp() //for ansible-playbook to to run always
  }  
  provisioner "local-exec" {
    command = "cat ansible/output.txt"
  }
}

#resource "null_resource" "destroy" {
#  depends_on = [module.deploy_instances]
#  triggers = {
#    master_ip = module.deploy_instances.master_ip
#    user_name = local.user_name
#    file_key = "${module.deploy_instances.key}"#################Need do not through file but get value of key, otherwise will be error because file hasn't created yet
#  }
#
#  provisioner "remote-exec" {
#    when = destroy
#    #inline = ["aws ec2 delete-volume --volume-id $(kubectl get pv `kubectl get pv -n my-project -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'` -n my-project -o jsonpath='{.spec.csi.volumeHandle}') --region eu-north-1"]
#    inline = [
#      "echo Startingdelete",
#    ]
#    connection {
#      host        = self.triggers.master_ip
#      type        = "ssh"
#      user        = self.triggers.user_name
#      private_key = self.triggers.file_key
#    } 
#    on_failure = continue   
#  }
#}