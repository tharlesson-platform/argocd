output "argocd_namespace" {
  description = "Namespace where Argo CD was installed."
  value       = kubernetes_namespace.argocd.metadata[0].name
}
