### ALB
resource "aws_security_group" "alb_sg" {
  vpc_id      = lookup(module.vpcs, "app").id
  description = "alb-sg"
  tags = {
    Name = "alb-sg"
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

resource "aws_security_group_rule" "alb_egress_80_to_vpc_for_asg_instances" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["10.0.0.0/20"]
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
}

### ASG Instance
resource "aws_security_group" "instance_sg" {
  vpc_id      = lookup(module.vpcs, "app").id
  description = "instance-sg"
  tags = {
    Name = "instance-sg"
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

# needed to access s3 endpoints
resource "aws_security_group_rule" "instance_egress_s3_us_west_2" {
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

# egress for msyql connections to rds
resource "aws_security_group_rule" "instance_egress_3306_to_vpc_for_asg_instances_access_to_rds" {
  security_group_id = aws_security_group.instance_sg.id
  cidr_blocks       = ["10.0.0.0/20"]
  type              = "egress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
}

### MySQL
resource "aws_security_group" "mysql_sg" {
  name        = "mysql-sg"
  vpc_id      = lookup(module.vpcs, local.tiered_vpc_names.app).id
  description = "mysql-sg"
  tags = {
    Name = "mysql-sg"
  }
}

resource "aws_security_group_rule" "mysql_ingress" {
  security_group_id        = aws_security_group.mysql_sg.id
  source_security_group_id = aws_security_group.instance_sg.id
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
}

# needed for rds to connect to other aws services
resource "aws_security_group_rule" "mysql_egress" {
  security_group_id = aws_security_group.mysql_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = -1
}

