variable "env_prefix" {
  description = "prod, stage, test"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "alb" {
  description = "ALB configuration specific to Cloud Infra Lab"
  type = object({
    name = string
    zone = object({
      name    = string
      zone_id = string
    })
    domain_name        = string
    security_group_ids = list(string)
    vpc = object({
      id = string
    })
    subnet_ids = list(string)
    target_group_health_check = optional(object({
      path                = optional(string, "/")
      matcher             = optional(string, "200")
      healthy_threshold   = optional(number, 3)
      unhealthy_threshold = optional(number, 3)
      interval            = optional(number, 30)
      timeout             = optional(number, 5)
    }), {})
    ssl_policy = optional(string, "ELBSecurityPolicy-TLS13-1-0-2021-06")
  })

  validation {
    condition     = var.alb.domain_name != var.alb.zone.name
    error_message = "There is no apex domain support at this time, use a subdomain of the zone for domain_name."
  }
}

