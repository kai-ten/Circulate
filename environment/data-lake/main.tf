data "aws_availability_zones" "available" {}

data "terraform_remote_state" "vpc_output" {
  backend = "s3"
  config = {
    bucket = "${var.name}-${var.env}-terraform-state-backend"
    key    = "vpc/terraform.tfstate"
    region = "us-east-2"
  }
}

// This bucket is intended for long term storage in S3, used as a data lake before being loaded downstream to other tools. 
// Must be defined as a target in a union
module "circulate_data_lake" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket            = "${var.name}-${var.env}-data"
  block_public_acls = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning = {
    enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "circulate_data_lake_private" {
  bucket = module.circulate_data_lake.s3_bucket_id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// This bucket holds temp data for step functions during the source API call
// This data is then removed after 3 days
module "circulate_data_lake_sfn_tmp" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket            = "${var.name}-${var.env}-sfn-tmp"
  block_public_acls = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
  
  lifecycle_rule = [
    {
      id      = "sfn-tmp-data"
      enabled = true

      expiration = {
        days = 3
      }
    }
  ]

  versioning = {
    enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "circulate_data_lake_sfn_tmp_private" {
  bucket = module.circulate_data_lake_sfn_tmp.s3_bucket_id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "circulate_iac" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket            = "${var.name}-${var.env}-iac"
  block_public_acls = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning = {
    enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "circulate_iac_private" {
  bucket = module.circulate_iac.s3_bucket_id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "efs" {
  source = "terraform-aws-modules/efs/aws"

  name           = "${var.name}-${var.env}-efs"
  creation_token = "${var.name}-${var.env}-efs"
  encrypted      = true

  performance_mode                = "generalPurpose"
  throughput_mode                 = "bursting"

  # Mount targets are generated to look like:
  # "us-east-2a" = {
  #    subnet_id = "subnet-abcde012"
  #  }
  mount_targets              = { 
    for k, v in zipmap(
      slice(data.aws_availability_zones.available.names, 0, 3), 
      data.terraform_remote_state.vpc_output.outputs.vpc_private_subnets
    ) : k => { subnet_id = v } 
  }

  security_group_name = "${var.name}-${var.env}_efs_sg"
  security_group_description = "Circulate EFS security group"
  security_group_vpc_id      = data.terraform_remote_state.vpc_output.outputs.vpc_id
  security_group_rules = {
    vpc = {
      # relying on the defaults provdied for EFS/NFS (2049/TCP + ingress)
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = data.terraform_remote_state.vpc_output.outputs.vpc_private_subnet_cidrs
    }
  }
}
