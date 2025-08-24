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
    instance_refresh = bool
    min_size         = number
    max_size         = number
    # will launch with initial desired_capacity value
    # but any updates will be ignored so that the sale in and scale out alarms takeover
    # uncomment lifecyle ignore changes for desired_capacity in the asg.
    desired_capacity          = number
    health_check_grace_period = optional(number, 300)
    instance_type             = optional(string, "t2.micro")
    cloudwatch_alarms = optional(object({
      cpu_low = optional(object({
        evaluation_periods = optional(number, 2)
        period             = optional(number, 60)
        threshold          = optional(number, 30)
        description        = optional(string, "Scale in if CPU < 30% for 2 minutes")
      }), {})
      cpu_high = optional(object({
        evaluation_periods = optional(number, 2)
        period             = optional(number, 60)
        threshold          = optional(number, 70)
        description        = optional(string, "Scale out if CPU > 70% for 2 minutes")
      }), {})
    }), {})
  })
}

