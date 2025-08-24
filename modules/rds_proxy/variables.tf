variable "env_prefix" {
  description = "prod, stage, test"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "rds_proxy" {
  description = "RDS Proxy configuration (RDS DB Instance and MYSQL specific for Cloud Infra Lab)"
  type = object({
    name = string
    rds = object({
      # Assume MySQL by default
      engine_family      = optional(string, "MYSQL")
      primary_identifier = string
      primary_address    = string
    })
    secretsmanager_secret = object({
      arn = string
    })
    security_group_ids = list(string)
    subnet_ids         = list(string)
    require_tls        = optional(bool, true)
    # This helps recycle pinned client connections faster without being too aggressive insead of 1800 default
    idle_client_timeout = optional(number, 900)
    debug_logging       = optional(bool, false)
    default_target_group_connection_pool_config = optional(object({
      # Steady web/ECS/EKS app – balanced reuse, moderate queueing
      # `session_pinning_filters` can reduce session pinning from SET statements
      # and improve multiplexing—use only if safe for your app’s session semantics.
      # tune to your needs
      max_connections_percent      = optional(number, 85)
      max_idle_connections_percent = optional(number, 40)
      connection_borrow_timeout    = optional(number, 10)
      session_pinning_filters      = optional(list(string), ["EXCLUDE_VARIABLE_SETS"]) # MYSQL Engine specific
    }), {})
  })
}

