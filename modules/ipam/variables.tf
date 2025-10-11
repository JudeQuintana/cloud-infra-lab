variable "env_prefix" {
  description = "prod, stage, test"
  type        = string
}

variable "ipam" {
  description = "ASG configuration specific to Cloud Infra Lab"
  type = object({
    name = string
    # addtional operating regions, the provider region will be added automatically
    operating_regions = optional(list(string), [])
    provision_cidrs   = list(string)
  })
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

