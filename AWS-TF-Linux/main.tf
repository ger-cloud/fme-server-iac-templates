terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "ca-central-1"
  default_tags {
    tags = {
      "Owner"   = var.owner
      "Purpose" = var.purpose
    }
  }
}

variable "key_name" {
  type = string
}

variable "owner" {
  type = string
}

variable "purpose" {
  type = string
}

data "template_file" "mainScript" {
  template = file("./install_fme.sh.tpl")
  vars = {
    efs        = aws_efs_file_system.FMEServerSystemShareEFS.id
    eip        = aws_eip.FMECoreEIP.public_ip
    rdsAddress = aws_db_instance.FMEDatabase.address
    rdsPort    = aws_db_instance.FMEDatabase.port
  }
}

data "template_file" "engineScript" {
  template = file("./install_engine.sh.tpl")
  vars = {
    efs        = aws_efs_file_system.FMEServerSystemShareEFS.id
    eip        = aws_eip.FMECoreEIP.public_ip
    rdsAddress = aws_db_instance.FMEDatabase.address
    rdsPort    = aws_db_instance.FMEDatabase.port
  }
}

module "network" {
  source = "./modules"
}

resource "aws_db_instance" "FMEDatabase" {
  allocated_storage      = 20
  availability_zone      = "ca-central-1a"
  instance_class         = "db.t3.micro"
  engine                 = "postgres"
  username               = "postgres"
  password               = "postgres"
  db_subnet_group_name   = module.network.dbSubnet
  license_model          = "postgresql-license"
  port                   = 5432
  multi_az               = false
  vpc_security_group_ids = [module.network.securityGroupID]
  skip_final_snapshot    = true
  tags = {
    "Name"    = "FMEDatabase"
  }
}

resource "aws_efs_file_system" "FMEServerSystemShareEFS" {
  availability_zone_name = "ca-central-1a"
  tags = {
    "Name"    = "FMEServerSystemShareEFS"
  }
}

resource "aws_efs_mount_target" "mountTarget" {
  file_system_id  = aws_efs_file_system.FMEServerSystemShareEFS.id
  subnet_id       = module.network.subnet
  security_groups = [module.network.securityGroupID]
}

resource "aws_eip" "FMECoreEIP" {
  vpc = true
  tags = {
    "Name" = "FMECoreEIP"
  }
}

resource "aws_eip_association" "associateEIP" {
  allocation_id = aws_eip.FMECoreEIP.id
  instance_id   = aws_instance.coreServer.id
}

resource "aws_instance" "coreServer" {
  ami                    = "ami-0801628222e2e96d6"
  availability_zone      = "ca-central-1a"
  instance_type          = "t3.medium"
  key_name               = var.key_name
  vpc_security_group_ids = [module.network.securityGroupID]
  subnet_id              = module.network.subnet
  root_block_device {
    volume_size = 20
  }
  user_data = data.template_file.mainScript.rendered
  depends_on = [
    aws_db_instance.FMEDatabase,
    aws_efs_mount_target.mountTarget,
    aws_eip.FMECoreEIP
  ]
  tags = {
    Name = "Core Instance"
  }
}

resource "aws_instance" "engineServer" {
  ami                         = "ami-0801628222e2e96d6"
  availability_zone           = "ca-central-1a"
  instance_type               = "t3.medium"
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [module.network.securityGroupID]
  subnet_id                   = module.network.subnet
  root_block_device {
    volume_size = 20
  }
  user_data = data.template_file.engineScript.rendered
  depends_on = [
    aws_instance.coreServer
  ]
  tags = {
    Name = "Engine Instance"
  }
}

output "FMEWebUI" {
  value = format("http://%s:8080/fmeserver", aws_eip.FMECoreEIP.public_ip)
}