### ALB
locals {
  alb_sg_name = format(local.name_fmt, var.env_prefix, "alb-sg")
}

resource "aws_security_group" "alb_sg" {
  name   = local.alb_sg_name
  vpc_id = lookup(module.vpcs, local.vpc_names.app).id

  tags = {
    Name = local.alb_sg_name
  }
}

locals {
  # change from allow from any to only allow specific IPs for 80 and 443
  alb_ingress_cidrs = ["0.0.0.0/0"]
}

# for http to https redirect
resource "aws_security_group_rule" "alb_ingress_80_from_any" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = local.alb_ingress_cidrs
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
}

resource "aws_security_group_rule" "alb_ingress_443_from_any" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = local.alb_ingress_cidrs
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
}

resource "aws_security_group_rule" "alb_egress_80_to_instance_sg" {
  security_group_id        = aws_security_group.alb_sg.id
  source_security_group_id = aws_security_group.instance_sg.id
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
}

### ASG Instance
locals {
  instance_sg_name = format(local.name_fmt, var.env_prefix, "instance-sg")
}

resource "aws_security_group" "instance_sg" {
  name   = local.instance_sg_name
  vpc_id = lookup(module.vpcs, local.vpc_names.app).id

  tags = {
    Name = local.instance_sg_name
  }
}

# only allow access from alb
resource "aws_security_group_rule" "instance_ingress_80_from_alb_sg" {
  security_group_id        = aws_security_group.instance_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
}

# needed to access s3 endpoints in us-west-2 region according to https://ip-ranges.amazonaws.com/ip-ranges.json
resource "aws_security_group_rule" "instance_egress_443_to_s3_us_west_2" {
  security_group_id = aws_security_group.instance_sg.id
  cidr_blocks = [
    "3.5.76.0/22",
    "18.34.244.0/22",
    "18.34.48.0/20",
    "3.5.80.0/21",
    "52.218.128.0/17",
    "52.92.128.0/17",
    "35.80.36.208/28",
    "35.80.36.224/28"
  ]
  type      = "egress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"
}

# need direct access for read replica bypassing RDS proxy
# required for RDS Instances behind RDS proxy
resource "aws_security_group_rule" "instance_egress_3306_to_mysql_sg" {
  security_group_id        = aws_security_group.instance_sg.id
  source_security_group_id = aws_security_group.mysql_sg.id
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
}

# egress for instance connections to rds proxy
resource "aws_security_group_rule" "instance_egress_3306_to_rds_proxy_sg" {
  security_group_id        = aws_security_group.instance_sg.id
  source_security_group_id = aws_security_group.rds_proxy_sg.id
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
}

### MySQL
locals {
  mysql_sg_name = format(local.name_fmt, var.env_prefix, "mysql-sg")
}

resource "aws_security_group" "mysql_sg" {
  name   = local.mysql_sg_name
  vpc_id = lookup(module.vpcs, local.vpc_names.app).id

  tags = {
    Name = local.mysql_sg_name
  }
}

resource "aws_security_group_rule" "mysql_ingress_3306_from_instance_sg" {
  security_group_id        = aws_security_group.mysql_sg.id
  source_security_group_id = aws_security_group.instance_sg.id
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "mysql_ingress_3306_from_rds_proxy_sg" {
  security_group_id        = aws_security_group.mysql_sg.id
  source_security_group_id = aws_security_group.rds_proxy_sg.id
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
}

# needed for rds to connect to other aws services
resource "aws_security_group_rule" "mysql_egress_all_to_any" {
  security_group_id = aws_security_group.mysql_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
}

### RDS Proxy
resource "aws_security_group" "rds_proxy_sg" {
  name   = format("%s-%s", var.env_prefix, "rds-proxy-sg")
  vpc_id = lookup(module.vpcs, local.vpc_names.app).id

  tags = {
    Name = format("%s-%s", var.env_prefix, "rds-proxy-sg")
  }
}

resource "aws_security_group_rule" "rds_proxy_ingress_3306_from_instance_sg" {
  security_group_id        = aws_security_group.rds_proxy_sg.id
  source_security_group_id = aws_security_group.instance_sg.id
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "rds_proxy_egress_3306_to_mysql_sg" {
  security_group_id        = aws_security_group.rds_proxy_sg.id
  source_security_group_id = aws_security_group.mysql_sg.id
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
}

