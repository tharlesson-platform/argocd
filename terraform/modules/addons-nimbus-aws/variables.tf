variable "cluster_name" {
  description = "Kubernetes cluster name."
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN used by the cluster."
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL used by the cluster."
  type        = string
}

variable "region" {
  description = "AWS region used by the cluster and the secret store."
  type        = string
}

variable "domain_name" {
  description = "Base DNS domain used by Argo CD ingress."
  type        = string
}

variable "gitops_repo_url" {
  description = "Git repository URL consumed by Argo CD."
  type        = string
}

variable "gitops_repo_revision" {
  description = "Git revision used by the root application."
  type        = string
  default     = "main"
}

variable "gitops_root_path" {
  description = "Path to the Nimbus root app inside the GitOps repository."
  type        = string
  default     = "argocd/root-app-nimbus-aws"
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

variable "ingress_nginx_chart_version" {
  type    = string
  default = "4.11.3"
}

variable "tags" {
  description = "Tags propagated to AWS resources created by the module."
  type        = map(string)
  default     = {}
}
