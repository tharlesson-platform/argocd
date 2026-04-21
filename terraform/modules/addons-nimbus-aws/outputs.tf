output "argocd_namespace" {
  description = "Namespace where Argo CD was installed."
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "external_secrets_role_arn" {
  description = "IAM role ARN used by External Secrets Operator."
  value       = aws_iam_role.external_secrets.arn
}
