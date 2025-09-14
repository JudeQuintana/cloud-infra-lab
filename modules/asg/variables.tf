variable "env_prefix" {
  description = "prod, stage, test"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "asg" {
  description = "ASG configuration specific to Cloud Infra Lab"
  type = object({
    name = string
    ami = object({
      id = string
    })
    user_data          = string
    security_group_ids = list(string)
    subnet_ids         = list(string)
    alb = object({
      target_group_arn = string
    })
    min_size = number
    max_size = number
    # will launch with initial desired_capacity value
    # but any updates will be ignored so that the sale in and scale out alarms takeover
    # uncomment lifecyle ignore changes for desired_capacity in the asg.
    desired_capacity = number
    instance_type    = string
    # optional key pair name for use when troubleshooting instances via ssh from a bastion host
    key_name = optional(string)
    # start a launch-before-terminate asg instance refresh using the latest launch template automatically after the launch template is modified
    instance_refresh          = optional(bool, true)
    health_check_grace_period = optional(number, 120)
    # root volume
    ebs = optional(object({
      root_volume_type = optional(string, "gp3")
      root_volume_size = optional(number, 8)
    }), {})
    cloudwatch_alarms = optional(object({
      cpu_high = optional(object({
        evaluation_periods = optional(number, 2)
        period             = optional(number, 60)
        threshold          = optional(number, 70)
        description        = optional(string, "Scale out if CPU > 70% for 2 minutes")
      }), {})
      cpu_low = optional(object({
        evaluation_periods = optional(number, 2)
        period             = optional(number, 60)
        threshold          = optional(number, 30)
        description        = optional(string, "Scale in if CPU < 30% for 2 minutes")
      }), {})
    }), {})
  })

  validation {
    condition     = var.asg.cloudwatch_alarms.cpu_high.threshold > 0 && var.asg.cloudwatch_alarms.cpu_high.threshold <= 100
    error_message = "The cpu high threshold number should be greather than 0 and less than or equal to 100"
  }

  validation {
    condition     = var.asg.cloudwatch_alarms.cpu_low.threshold > 0 && var.asg.cloudwatch_alarms.cpu_low.threshold <= 100
    error_message = "The cpu low threshold number should be greater than 0 and less than or equal to 100"
  }
}

