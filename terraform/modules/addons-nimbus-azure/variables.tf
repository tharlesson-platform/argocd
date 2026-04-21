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
  default     = "argocd/root-app-nimbus-azure"
}

variable "key_vault_url" {
  description = "Key Vault URL used by External Secrets Operator."
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID used by External Secrets Operator."
  type        = string
}

variable "external_secrets_identity_client_id" {
  description = "Client ID of the user-assigned identity used by External Secrets Operator."
  type        = string
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
