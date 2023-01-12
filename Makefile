ENV ?= dev



#########################
# Configure Environment #
#########################

# 1. Create remote backend
# 2. Create workspaces
# 3. Depending on make env var, select workspace to deploy into



######################
# Initialize Backend #
######################
backend:
	cd iac/remote-backend && \
	terraform init && \
	terraform apply -auto-approve --var-file=env/$(ENV).tfvars


######################
# Initialize Modules #
######################

init-infra-vpc:
	cd iac/vpc && terraform init

init-infra-database:
	cd iac/database && terraform init

init-infra-services-okta:
	cd iac/services/okta && terraform init

init-infra-services-create-database:
	cd iac/services/utils/database-configurator/create-database && terraform init

init: init-infra-vpc init-infra-database init-infra-services-okta init-infra-services-create-database



###################
# Apply Resources #
###################

apply-infra-vpc:
	cd iac/vpc && \
	terraform apply --var-file=env/$(ENV).tfvars

apply-infra-database:
	cd iac/database && \
	terraform apply --var-file=env/$(ENV).tfvars

apply: apply-infra-vpc apply-infra-database




########################
# Auto-apply Resources #
########################

auto-apply-infra-vpc:
	cd iac/vpc && \
	terraform apply -auto-approve --var-file=env/$(ENV).tfvars

auto-apply-infra-database:
	cd iac/database && \
	terraform apply -auto-approve --var-file=env/$(ENV).tfvars

auto-apply-infra-services-okta:
	cd iac/services/okta && \
	terraform apply -auto-approve --var-file=env/$(ENV).tfvars

auto-apply-infra-services-create-database:
	cd iac/services/utils/database-configurator/create-database && \
	terraform apply -auto-approve --var-file=env/$(ENV).tfvars

auto-apply: auto-apply-infra-vpc auto-apply-infra-database auto-apply-infra-services-okta auto-apply-infra-services-create-database



#####################
# Destroy Resources #
#####################

auto-destroy-infra-vpc:
	cd iac/vpc && \
	terraform destroy -auto-approve --var-file=env/$(ENV).tfvars

auto-destroy-infra-database:
	cd iac/database && \
	terraform destroy -auto-approve --var-file=env/$(ENV).tfvars

auto-destroy-infra-services-okta:
	cd iac/services/okta && \
	terraform destroy -auto-approve --var-file=env/$(ENV).tfvars

auto-destroy-infra-services-create-database:
	cd iac/services/utils/database-configurator/create-database && \
	terraform destroy -auto-approve --var-file=env/$(ENV).tfvars

auto-destroy: auto-destroy-infra-services-create-database \
	auto-destroy-infra-services-okta \
	auto-destroy-infra-database \
	auto-destroy-infra-vpc



####################
# Format Resources #
####################

fmt:
	cd iac/vpc && \
	terraform fmt && \
	cd - && \
	cd iac/database && \
	terraform fmt && \
	cd - && \
	cd iac/services/okta && \
	terraform fmt