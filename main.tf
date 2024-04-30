provider "aws" {
  region = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

module "network" {
  source = "./modules/network"
}

module "ecs" {
  source = "./modules/ecs"

  region         = var.region
  account_id     = var.account_id
  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.subnet_ids
  security_group_id = module.network.security_group_id
}
