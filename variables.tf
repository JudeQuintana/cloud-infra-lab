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
  description = "Name of existing Route53 DNS zone."
  type        = string
  default     = "jq1.io"
}

variable "enable_ipam" {
  description = "Must decide to wether or not to toggle to enable IPAM module prior to first apply."
  type        = bool
  default     = false
}

variable "enable_ssm" {
  description = "Toggle for enabling SSM dependencies for ASG Instances when needed. Toggle anytime."
  type        = bool
  default     = false
}

variable "enable_rds_proxy" {
  description = "Toggle for enabling RDS Proxy when needed. Toggle anytime."
  type        = bool
  default     = false
}

