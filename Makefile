ACCOUNT := $(shell aws sts get-caller-identity --query Account --output text)
ADMIN   := $(shell aws sts get-caller-identity --query Arn --output text)
TFVARS  := -var="key_admin_arns=[\"$(ADMIN)\"]"
DIR     := infra/environments/dev

plan:
	cd $(DIR) && terraform plan $(TFVARS)

apply:
	cd $(DIR) && terraform apply $(TFVARS)

destroy:
	cd $(DIR) && terraform destroy $(TFVARS)

bootstrap:
	cd $(DIR) && terraform apply $(TFVARS) \
	  -target=aws_s3_bucket.terraform_state \
	  -target=aws_dynamodb_table.terraform_locks

init:
	cd $(DIR) && terraform init -reconfigure

fmt:
	terraform fmt -recursive

validate:
	cd $(DIR) && terraform validate

.PHONY: plan apply destroy bootstrap init fmt validate
