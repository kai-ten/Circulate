data "aws_ssm_parameter" "private_subnet_group_name" {
  name = "/${var.name}-${var.env}/private-subnet-group/name"
}

data "aws_ssm_parameter" "security_group_id" {
  name = "/${var.name}-${var.env}/security-group/id"
}

data "aws_iam_role" "managed_rds_role" {
  name = "AWSServiceRoleForRDS"
}

resource "random_password" "password" {
  length           = 19
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "${var.name}-${var.env}"

  engine                = "postgres"
  engine_version        = "14"
  family                = "postgres14"
  major_engine_version  = "14"
  instance_class        = var.instance_type
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  db_name                             = "circulatedb"
  username                            = "root"
  password                            = random_password.password.result
  port                                = 5432
  iam_database_authentication_enabled = false // TODO: Implement for improved access control

  multi_az               = var.is_multi_az
  db_subnet_group_name   = data.aws_ssm_parameter.private_subnet_group_name.value
  vpc_security_group_ids = [data.aws_ssm_parameter.security_group_id.value]
  publicly_accessible    = var.is_public

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  create_cloudwatch_log_group     = true

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_interval                   = 60
  monitoring_role_name                  = "circulate-monitoring-role"
  monitoring_role_use_name_prefix       = true
  monitoring_role_description           = "Description for monitoring role"

  parameters = [
    {
      name  = "autovacuum"
      value = 1
    },
    {
      name  = "client_encoding"
      value = "utf8"
    }
  ]

  db_option_group_tags = {
    "Sensitive" = "low"
  }
  db_parameter_group_tags = {
    "Sensitive" = "low"
  }
}

resource "aws_db_instance_role_association" "rds_lambda_iam_assn" {
  db_instance_identifier = module.db.db_instance_id
  feature_name           = "Lambda"
  role_arn               = data.aws_iam_role.managed_rds_role.arn
}

resource "aws_secretsmanager_secret" "circulate_db" {
  name = "/${var.name}-${var.env}/postgresdb/dbsecret"
}

resource "aws_secretsmanager_secret_version" "circulate_db_password_version" {
  secret_id     = aws_secretsmanager_secret.circulate_db.id
  secret_string = <<EOF
   {
    "username": "root",
    "password": "${random_password.password.result}",
    "engine": "postgres14",
    "host": "${module.db.db_instance_endpoint}"
   }
EOF
}

resource "aws_ssm_parameter" "database_url_output" {
  name  = "/${var.name}-${var.env}/postgresdb/host"
  type  = "String"
  value = module.db.db_instance_endpoint
}
