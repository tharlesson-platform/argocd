variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "cluster_endpoint" {
  type        = string
  description = "EKS API endpoint"
}

variable "cluster_ca_certificate" {
  type        = string
  description = "Base64 cluster CA cert"
}

variable "oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN"
}

variable "oidc_provider_url" {
  type        = string
  description = "OIDC provider URL"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "vpc_id" {
  type        = string
  description = "VPC id"
}

variable "domain_name" {
  type        = string
  description = "Base DNS domain"
}

variable "gitops_repo_url" {
  type        = string
  description = "Git repository URL used by Argo CD"
}

variable "gitops_repo_revision" {
  type        = string
  description = "Git revision for root app"
  default     = "main"
}

variable "gitops_root_path" {
  type        = string
  description = "Path for root app manifests"
  default     = "argocd/root-app"
}

variable "argocd_chart_version" {
  type    = string
  default = "6.11.0"
}

variable "argo_rollouts_chart_version" {
  type    = string
  default = "2.37.6"
}

variable "kube_prometheus_stack_version" {
  type    = string
  default = "62.3.1"
}

variable "external_secrets_chart_version" {
  type    = string
  default = "0.10.5"
}

variable "aws_load_balancer_controller_chart_version" {
  type    = string
  default = "1.9.1"
}

variable "kyverno_chart_version" {
  type    = string
  default = "3.3.7"
}

variable "karpenter_chart_version" {
  type    = string
  default = "1.9.0"
}

variable "karpenter_namespace" {
  type    = string
  default = "karpenter"
}

variable "karpenter_service_account" {
  type    = string
  default = "karpenter"
}

variable "tags" {
  type    = map(string)
  default = {}
}
