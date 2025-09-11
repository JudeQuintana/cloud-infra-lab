### ALB
module "alb_security_group" {
  source = "./modules/security_group"

  env_prefix = var.env_prefix
  security_group = {
    name = "alb"
    vpc  = local.app_vpc
    rules = [
      {
        id          = "ingress-tcp-443-from-any"
        cidr_blocks = ["0.0.0.0/0"]
        type        = "ingress"
        protocol    = "tcp"
        from_port   = 443
        to_port     = 443
      },
      {
        # needed for http to https redirect
        id          = "ingress-tcp-80-from-any"
        cidr_blocks = ["0.0.0.0/0"]
        type        = "ingress"
        protocol    = "tcp"
        from_port   = 80
        to_port     = 80
      },
      {
        id                       = "egress-tcp-80-to-instance"
        source_security_group_id = module.instance_security_group.id
        type                     = "egress"
        protocol                 = "tcp"
        from_port                = 80
        to_port                  = 80
      }
    ]
  }
}

### ASG Instance
module "instance_security_group" {
  source = "./modules/security_group"

  env_prefix = var.env_prefix
  security_group = {
    name = "instance"
    vpc  = local.app_vpc
    rules = [
      {
        id                       = "ingress-tcp-80-from-alb"
        source_security_group_id = module.alb_security_group.id
        type                     = "ingress"
        from_port                = 80
        to_port                  = 80
        protocol                 = "tcp"
      },
      {
        # need direct access for read replica bypassing RDS proxy
        id                       = "egress-tcp-3306-to-rds"
        source_security_group_id = module.rds_security_group.id
        type                     = "egress"
        protocol                 = "tcp"
        from_port                = 3306
        to_port                  = 3306
      },
      {
        id                       = "egress-tcp-3306-to-rds-proxy"
        source_security_group_id = module.rds_proxy_security_group.id
        type                     = "egress"
        protocol                 = "tcp"
        from_port                = 3306
        to_port                  = 3306
      },
      {
        # needed to access s3 endpoints in us-west-2 region according to https://ip-ranges.amazonaws.com/ip-ranges.json
        id = "egress-tcp-443-to-s3-us-west-2"
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
    ]
  }
}

### RDS MySQL
module "rds_security_group" {
  source = "./modules/security_group"

  env_prefix = var.env_prefix
  security_group = {
    name = "rds"
    vpc  = local.app_vpc
    rules = [
      {
        id                       = "ingress-tcp-3306-from-instance"
        source_security_group_id = module.instance_security_group.id
        type                     = "ingress"
        protocol                 = "tcp"
        from_port                = 3306
        to_port                  = 3306
      },
      {
        id                       = "ingress-tcp-3306-from-rds-proxy"
        source_security_group_id = module.rds_proxy_security_group.id
        type                     = "ingress"
        protocol                 = "tcp"
        from_port                = 3306
        to_port                  = 3306
      },
      {
        # needed for rds to connect to other aws services
        id                = "egress_all_to_any"
        security_group_id = module.rds_security_group.id
        cidr_blocks       = ["0.0.0.0/0"]
        type              = "egress"
        protocol          = "-1"
        from_port         = 0
        to_port           = 0
      }
    ]
  }
}

### RDS Proxy
module "rds_proxy_security_group" {
  source = "./modules/security_group"

  env_prefix = var.env_prefix
  security_group = {
    name = "rds-proxy"
    vpc  = local.app_vpc
    rules = [
      {
        id                       = "ingress-tcp-3306-from-instance"
        source_security_group_id = module.instance_security_group.id
        type                     = "ingress"
        protocol                 = "tcp"
        from_port                = 3306
        to_port                  = 3306
      },
      {
        id                       = "egress-tcp-3306-to-rds"
        source_security_group_id = module.rds_security_group.id
        type                     = "egress"
        protocol                 = "tcp"
        from_port                = 3306
        to_port                  = 3306
      }
    ]
  }
}

