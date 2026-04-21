# Modulo `addons-nimbus-azure`

Instala o bootstrap GitOps do Nimbus sobre um cluster Kubernetes/Azure:

- Argo CD
- Argo Rollouts
- ingress-nginx
- External Secrets Operator com Azure Key Vault e Workload Identity
- kube-prometheus-stack
- root application do Nimbus

O módulo assume que os providers `helm` e `kubernetes` já estão configurados pelo stack consumidor.
