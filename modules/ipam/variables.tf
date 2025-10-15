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

  # using ipv4 validation via cidrnetmask function instead of regex for ipv4
  # caches most bad CIDR notations
  validation {
    condition = alltrue(flatten([
      for this in var.ipam.provision_cidrs : can(cidrnetmask(this))
    ]))
    error_message = "All CIDRs in var.ipam.provision_cidrs must be in valid IPv4 CIDR notation (ie x.x.x.x/xx -> 10.46.0.0/20). Check for typos."
  }
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

