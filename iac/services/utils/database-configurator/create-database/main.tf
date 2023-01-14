data "terraform_remote_state" "vpc_output" {
  backend = "s3"
  config = {
    bucket = "${var.name}-${var.env}-terraform-state-backend"
    key    = "vpc/terraform.tfstate"
    region = "us-east-2"
  }
}

data "terraform_remote_state" "postgresdb_output" {
  backend = "s3"
  config = {
    bucket = "${var.name}-${var.env}-terraform-state-backend"
    key    = "postgresdb/terraform.tfstate"
    region = "us-east-2"
  }
}

data "aws_secretsmanager_secret" "database_secret" {
  name = data.terraform_remote_state.postgresdb_output.outputs.database_secret_name
}

data "aws_iam_policy" "AWSLambdaVPCAccessExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "create_database_policy" {
  source_policy_documents = [data.aws_iam_policy.AWSLambdaVPCAccessExecutionRole.policy]

  statement {
    actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecrets"
      ]
    resources = [
      "${data.aws_secretsmanager_secret.database_secret.arn}"
    ]
  }
}

module "circulate_create_database" {
  source          = "../../../modules/go-lambda"
  name            = "${var.name}-${var.env}"
  lambda_name     = "${var.name}-${var.env}-${var.service}"
  src_path        = "../../../../../lib/utils/database-configurator/create-database"
  iam_policy_json = data.aws_iam_policy_document.create_database_policy.json
  timeout = 5
  vpc_config = {
    security_group_ids = [data.terraform_remote_state.vpc_output.outputs.vpc_security_group_id]
    subnet_ids = data.terraform_remote_state.vpc_output.outputs.vpc_public_subnets
  }
  env_variables = {
    "DATABASE_SECRET" = "${data.terraform_remote_state.postgresdb_output.outputs.database_secret_name}"
  }
}

resource "null_resource" "db_setup" {
  triggers = {
    resource = module.circulate_create_table.lambda_function.function_name # build triggers after resource exists
  }
  provisioner "local-exec" {
    command = <<-EOF
			aws lambda invoke --function-name "$FUNCTION_NAME" /dev/stdout 2>/dev/null
			EOF
    environment = {
      FUNCTION_NAME     = module.circulate_create_database.lambda_function.function_name
    }
    interpreter = ["bash", "-c"]
  }
}
