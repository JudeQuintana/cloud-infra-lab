variable "env_prefix" {
  description = "Environment prefix"
  type        = string
}

variable "security_group" {
  description = "Security Group config"
  type = object({
    name = string
    vpc = object({
      id = string
    })
    rules = optional(list(object({
      id                       = string
      source_security_group_id = optional(string)
      cidr_blocks              = optional(list(string))
      type                     = string
      protocol                 = string
      from_port                = number
      to_port                  = number
    })), [])
  })

  validation {
    condition = alltrue(
      [for this in var.security_group.rules : (this.source_security_group_id != null && this.cidr_blocks == null) || (this.source_security_group_id == null && this.cidr_blocks != null)]
    )
    error_message = "Security Group Rules can not have both the source_security_group_id and cidr_blocks set, they're mutually exclusive."
  }

  validation {
    condition = length(distinct(
      var.security_group.rules[*].id
    )) == length(var.security_group.rules[*].id)
    error_message = "Security Group Rules must have a unique id."
  }
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
