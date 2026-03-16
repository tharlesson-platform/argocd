SHELL := /usr/bin/env bash

ENV ?= dev
TF_DIR := terraform/environments/$(ENV)
DOMAIN ?= example.internal
ECR_IMAGE ?= <aws-account-id>.dkr.ecr.<region>.amazonaws.com/sample-api
STRATEGY ?= canary
CLUSTER_NAME ?= gitops-dev

.PHONY: help terraform-init terraform-fmt terraform-validate terraform-plan terraform-apply bootstrap validate-kustomize configure-domain configure-ecr configure-karpenter set-prod-strategy lint-sample test-sample build-sample

help:
	@echo "Targets:" \
	&& echo "  terraform-init ENV=dev" \
	&& echo "  terraform-fmt" \
	&& echo "  terraform-validate ENV=dev" \
	&& echo "  terraform-plan ENV=dev" \
	&& echo "  terraform-apply ENV=dev" \
	&& echo "  bootstrap ENV=dev" \
	&& echo "  validate-kustomize" \
	&& echo "  configure-domain DOMAIN=platform.example.com" \
	&& echo "  configure-ecr ECR_IMAGE=123456789012.dkr.ecr.us-east-1.amazonaws.com/sample-api" \
	&& echo "  configure-karpenter CLUSTER_NAME=gitops-dev" \
	&& echo "  set-prod-strategy STRATEGY=bluegreen" \
	&& echo "  lint-sample" \
	&& echo "  test-sample"

terraform-init:
	cd $(TF_DIR) && terraform init

terraform-fmt:
	terraform fmt -recursive

terraform-validate:
	cd $(TF_DIR) && terraform init -backend=false && terraform validate

terraform-plan:
	cd $(TF_DIR) && terraform init && terraform plan -var-file=terraform.tfvars

terraform-apply:
	cd $(TF_DIR) && terraform init && terraform apply -var-file=terraform.tfvars

bootstrap:
	./scripts/bootstrap.sh $(ENV)

validate-kustomize:
	./scripts/validate-manifests.sh

configure-domain:
	./scripts/configure-domain.sh $(DOMAIN)

configure-ecr:
	./scripts/configure-ecr.sh $(ECR_IMAGE)

configure-karpenter:
	./scripts/configure-karpenter.sh $(CLUSTER_NAME)

set-prod-strategy:
	./scripts/set-rollout-strategy.sh $(STRATEGY)

lint-sample:
	cd apps/sample-api/app && pip install ruff==0.11.0 && ruff check .

test-sample:
	cd apps/sample-api/app && pip install -r requirements.txt && pytest -q

build-sample:
	docker build -t sample-api:local apps/sample-api/app
