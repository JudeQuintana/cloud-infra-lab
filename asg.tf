data "aws_ami" "al2023" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  # demonstrating pulling from secretsmanager
  # should use separate writer and readonly creds instead of using admin creds to access the primary and read replica db's but used here for demo purposes
  secretsmanager_mysql = jsondecode(aws_secretsmanager_secret_version.rds.secret_string)

  # should use ssm intsead of rendering passwords direct into user data but good enough for now
  cloud_init = base64encode(templatefile(
    format("%s/templates/cloud_init.tftpl", path.module),
    merge(
      local.secretsmanager_mysql,
      { rds_proxy = var.enable_rds_proxy }
  )))
}

# It's difficult to test scale-out with no load testing scripts (at the moment) but you can test the scale-in by selecting a desired capacity of 6 and watch the asg terminate unneeded instance capacity down back to 2.
# will launch with initial desired_capacity value but any updates will be ignored so that the sale in and scale out alarms takeover
# uncomment lifecyle ignore changes for desired_capacity in the asg resource in the asg module.
module "asg" {
  source = "./modules/asg"

  env_prefix = var.env_prefix
  asg = {
    name               = "web"
    min_size           = 2
    max_size           = 8
    desired_capacity   = 2
    ami                = data.aws_ami.al2023
    instance_type      = "t2.micro"
    user_data          = local.cloud_init
    ssm                = var.enable_ssm
    alb                = module.alb
    security_group_ids = [aws_security_group.instance.id]
    subnet_ids = [
      lookup(local.app_vpc.private_subnet_name_to_subnet_id, "proxy1"),
      lookup(local.app_vpc.private_subnet_name_to_subnet_id, "proxy2")
    ]
  }
}

