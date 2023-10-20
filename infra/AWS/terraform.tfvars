########################## General ##########################
region           = "eu-central-1"
aws_profile_name = "default"

########################## Network ##########################
cidr             = "10.244.0.0/16"
public_subnets   = ["10.244.0.0/24", "10.244.1.0/24", "10.244.2.0/24"]
private_subnets  = ["10.244.13.0/24", "10.244.14.0/24", "10.244.15.0/24"]
database_subnets = ["10.244.26.0/24", "10.244.27.0/24", "10.244.28.0/24"]