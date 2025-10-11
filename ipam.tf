module "ipam" {
  source = "./modules/ipam"

  env_prefix = var.env_prefix
  ipam = {
    name            = "infra"
    provision_cidrs = ["10.0.0.0/18"]
  }
}
