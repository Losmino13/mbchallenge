terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

########################## Default region ##########################
provider "aws" {
  region  = "eu-central-1"
  shared_credentials_files = ["/Users/milosmilisavljevic/.aws/credentials_mbition"]
}

######################### Store Terraform state file into S3 bucket ##########################
terraform {
  backend "s3" {
    profile        = "default"
    bucket         = "mbition-terraform-state"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "mbition-terraform-state-lock"
  }
}

########################## aws_caller_identity ##########################
data "aws_caller_identity" "current" {}

########################## aws_region ##########################
data "aws_region" "current" {}

########################## aws_availability_zones ##########################
data "aws_availability_zones" "available" {
  state = "available"
}


################## S3 Bucket State ##################
resource "aws_s3_bucket" "terraform-state" {
  bucket = "mbition-terraform-state"
}
resource "aws_s3_bucket_logging" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  target_bucket = "mbition-terraform-state"
  target_prefix = "logs/"
}

resource "aws_s3_bucket_acl" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.terraform-state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################## Dynamo Table Lock ##################
resource "aws_dynamodb_table" "terraform-state" {
  name           = "mbition-terraform-state-lock"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "LockID"
    type = "S"
  }
}