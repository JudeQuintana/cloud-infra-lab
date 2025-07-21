variable "env_prefix" {
  description = "Environment prefix ie test, stg, prod."
  type        = string
  default     = "test"
}

variable "region_az_labels" {
  description = "Update this map with regions and AZs that will be in use for short name labeling."
  type        = map(string)
  default = {
    us-west-2  = "usw2"
    us-west-2a = "usw2a"
    us-west-2b = "usw2b"
    us-west-2c = "usw2c"
  }
}

variable "zone_name" {
  description = "Name of Route53 DNS zone."
  type        = string
  default     = "jq1.io"
}

variable "asg_instance_refresher" {
  description = "Start a launch-before-terminate asg instance refresh using the latest launch template automatically after the launch template user_data or image_id has been modified."
  type        = bool
  default     = true
}

variable "enable_natgws" {
  description = "NATGW toggle for each configured public subnet in each AZ (see vpcs.tf)."
  type        = bool
  default     = false
}

