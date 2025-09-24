locals {
  # only for sg tags since modules tag env themselves
  # cant combine sg and sg rules in a module due to cycle errors when using source_security_group_id
  # so keeping sg and sg rules separate for now ref: https://github.com/JudeQuintana/cloud-infra-lab/pull/16
  default_sg_tags = merge({
    Environment = var.env_prefix
  })
  sg_name_fmt       = "%s-%s"
  alb_sg_name       = format(local.sg_name_fmt, var.env_prefix, "alb")
  instance_sg_name  = format(local.sg_name_fmt, var.env_prefix, "instance")
  rds_sg_name       = format(local.sg_name_fmt, var.env_prefix, "rds")
  rds_proxy_sg_name = format(local.sg_name_fmt, var.env_prefix, "rds-proxy")
}

### ALB
resource "aws_security_group" "alb" {
  name   = local.alb_sg_name
  vpc_id = local.app_vpc.id

  tags = merge(
    local.default_sg_tags,
    {
      Name = local.alb_sg_name
    }
  )
}

# for http to https redirect
resource "aws_security_group_rule" "alb_ingress_tcp_80_from_any" {
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_security_group_rule" "alb_ingress_tcp_443_from_any" {
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_security_group_rule" "alb_egress_tcp_80_to_instance" {
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.instance.id
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
}

### ASG Instance
resource "aws_security_group" "instance" {
  name   = local.instance_sg_name
  vpc_id = local.app_vpc.id

  tags = merge(
    local.default_sg_tags,
    {
      Name = local.instance_sg_name
    }
  )
}

resource "aws_security_group_rule" "instance_ingress_tcp_80_from_alb" {
  security_group_id        = aws_security_group.instance.id
  source_security_group_id = aws_security_group.alb.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
}

# needed to access s3 endpoints in us-west-2 region according to https://ip-ranges.amazonaws.com/ip-ranges.json
resource "aws_security_group_rule" "instance_egress_tcp_443_to_s3_us_west_2" {
  security_group_id = aws_security_group.instance.id
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
  protocol  = "tcp"
  from_port = 443
  to_port   = 443
}

# need direct access for read replica bypassing RDS proxy
resource "aws_security_group_rule" "instance_egress_tcp_3306_to_rds" {
  security_group_id        = aws_security_group.instance.id
  source_security_group_id = aws_security_group.rds.id
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 3306
  to_port                  = 3306
}

# egress for instance connections to rds proxy
resource "aws_security_group_rule" "instance_egress_tcp_3306_to_rds_proxy" {
  security_group_id        = aws_security_group.instance.id
  source_security_group_id = aws_security_group.rds_proxy.id
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 3306
  to_port                  = 3306
}

### RDS MySQL
resource "aws_security_group" "rds" {
  name   = local.rds_sg_name
  vpc_id = local.app_vpc.id

  tags = merge(
    local.default_sg_tags,
    {
      Name = local.rds_sg_name
    }
  )
}

resource "aws_security_group_rule" "rds_ingress_tcp_3306_from_instance" {
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.instance.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 3306
  to_port                  = 3306
}

resource "aws_security_group_rule" "rds_ingress_tcp_3306_from_rds_proxy" {
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.rds_proxy.id
  protocol                 = "tcp"
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
}

# needed for rds to connect to other aws services
resource "aws_security_group_rule" "rds_egress_all_to_any" {
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
}

### RDS Proxy
resource "aws_security_group" "rds_proxy" {
  name   = local.rds_proxy_sg_name
  vpc_id = local.app_vpc.id

  tags = merge(
    local.default_sg_tags,
    {
      Name = local.rds_proxy_sg_name
    }
  )
}

# required for RDS Instances behind RDS proxy
resource "aws_security_group_rule" "rds_proxy_ingress_tcp_3306_from_instance" {
  security_group_id        = aws_security_group.rds_proxy.id
  source_security_group_id = aws_security_group.instance.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 3306
  to_port                  = 3306
}

resource "aws_security_group_rule" "rds_proxy_egress_tcp_3306_to_rds" {
  security_group_id        = aws_security_group.rds_proxy.id
  source_security_group_id = aws_security_group.rds.id
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 3306
  to_port                  = 3306
}

