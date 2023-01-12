output "vpc_public_subnets" {
  value = module.vpc.public_subnets
}

output "vpc_private_subnets" {
  value = module.vpc.private_subnets
}

output "vpc_database_subnet_group" {
  value = module.vpc.database_subnet_group
}

output "vpc_security_group_id" {
  value = module.security_group.security_group_id
}
