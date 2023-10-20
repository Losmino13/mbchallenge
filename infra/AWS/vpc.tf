module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.0"

  name             = "mbitiion"
  cidr             = var.cidr
  azs              = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_vpn_gateway      = false
  enable_dns_hostnames    = true
  map_public_ip_on_launch = false

}