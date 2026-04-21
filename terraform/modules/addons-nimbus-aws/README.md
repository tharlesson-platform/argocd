# Modulo `addons-nimbus-aws`

Instala o bootstrap GitOps do Nimbus sobre um cluster Kubernetes/AWS:

- Argo CD
- Argo Rollouts
- ingress-nginx
- External Secrets Operator com AWS Secrets Manager
- kube-prometheus-stack
- root application do Nimbus

O módulo assume que os providers `helm` e `kubernetes` já estão configurados pelo stack consumidor.
