data "aws_ami" "ami_latest" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["ubuntu/images/*20.04*"]
  }
}

#---Policy-Role-Master
resource "aws_iam_policy" "policy_master" {
  name   = "policy_master"
  path   = "/"
  policy = file("templates/policy_master.json")
  tags = {
    Name = "policy_master_${var.my_name}"
  }
}

resource "aws_iam_role" "role_master" {
  name               = "role_master"
  assume_role_policy = file("templates/role.json")
  tags = {
    Name = "role_master_${var.my_name}"
  }
}

resource "aws_iam_role_policy_attachment" "attach_policy_master_role_master" {
  role       = aws_iam_role.role_master.name
  policy_arn = aws_iam_policy.policy_master.arn
}

resource "aws_iam_role_policy_attachment" "attach_policy_ebs_role_master" {
  role       = aws_iam_role.role_master.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_instance_profile" "master_profile" {
  name = "master_profile"
  role = aws_iam_role.role_master.name
}
#------------------------------

#---Policy-Role-Worker
resource "aws_iam_policy" "policy_worker" {
  name   = "policy_worker"
  path   = "/"
  policy = file("templates/policy_worker.json")
  tags = {
    Name = "policy_worker_${var.my_name}"
  }
}

resource "aws_iam_role" "role_worker" {
  name               = "role_worker"
  assume_role_policy = file("templates/role.json")
  tags = {
    Name = "role_worker_${var.my_name}"
  }
}

resource "aws_iam_role_policy_attachment" "attach_policy_worker_role_worker" {
  role       = aws_iam_role.role_worker.name
  policy_arn = aws_iam_policy.policy_worker.arn
}

resource "aws_iam_role_policy_attachment" "attach_policy_ebs_role_worker" {
  role       = aws_iam_role.role_worker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "worker_profile"
  role = aws_iam_role.role_worker.name
}
#------------------------------

resource "aws_security_group" "sg" {
  name        = "sg"
  description = "SG for instance"
  vpc_id      = var.vpc_id

  /*dynamic "ingress" {
    for_each = var.port
    content {
      from_port        = ingress.value
      to_port          = ingress.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  }*/

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    #ipv6_cidr_blocks  = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    #ipv6_cidr_blocks  = ["::/0"]
  }

  tags = {
    Name = "sg_${var.my_name}"
  }
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "key.pem"
  public_key = tls_private_key.private_key.public_key_openssh
}

resource "local_file" "local_key_pair" {
  filename        = "${var.path_for_ansible}key.pem"
  file_permission = "0400"
  content         = tls_private_key.private_key.private_key_pem
}

resource "aws_instance" "instance_master" {
  ami                    = data.aws_ami.ami_latest.id
  instance_type          = var.instance_type_master
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.sg.id]
  iam_instance_profile = aws_iam_instance_profile.master_profile.name
  key_name               = aws_key_pair.generated_key.key_name
  root_block_device {
    delete_on_termination = true
    volume_size           = 8
    volume_type           = "gp3"
    tags = {
      Name = "${var.my_name}_ebs_master"
    }
  }
  tags = {
    Name = "${var.my_name}_master"
  }
}

resource "aws_instance" "instance_workers" {
  count                  = var.nm_worker
  ami                    = "ami-0989fb15ce71ba39e"
  instance_type          = var.instance_type_worker
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.sg.id]
  iam_instance_profile = aws_iam_instance_profile.worker_profile.name
  key_name               = aws_key_pair.generated_key.key_name
  root_block_device {
    delete_on_termination = true
    volume_size           = 8
    volume_type           = "gp3"
    tags = {
      Name = "${var.my_name}_ebs_worker_0${count.index + 1}"
    }
  }
  tags = {
    Name = "${var.my_name}_worker_0${count.index + 1}"
  }
}

resource "aws_eip_association" "eip_assoc_master" {
  instance_id   = aws_instance.instance_master.id
  allocation_id = aws_eip.eip_master.id//"eipalloc-041efad485b4eb529"
}

resource "aws_eip_association" "eip_assoc_workers" {
  count         = var.nm_worker
  instance_id   = element(aws_instance.instance_workers.*.id, count.index) //It's possible so and so
  allocation_id = aws_eip.eip_workers[count.index].id                      //It's possible so and so
}

resource "aws_eip" "eip_master" {
  //instance = aws_instance.instance_master.id
  domain = "vpc"
}

resource "aws_eip" "eip_workers" {
  count = var.nm_worker
  //instance = element(aws_instance.instance_workers[*].id, count.index)
  domain = "vpc"
}