# Fluxo de Promoção (somente Git)

## Princípios

- CI nunca executa `kubectl apply` para deploy de aplicação.
- Promoção é uma mudança em Git no overlay do ambiente de destino.
- Argo CD reconcilia mudanças do Git após merge.

## Runner local

Provisione uma VM descartável por job com o label `argocd-run-<run_id>`.
Confira repositório, workflow, branch, SHA e job na fila antes de registrar
o runner. A conta do job fica sem privilégios administrativos e sem acesso ao
socket Docker do host. O build da imagem usa Podman rootless e preserva
`linux/amd64`. No Mac ARM, a VM de build usa Rosetta para executar essa arquitetura.

O smoke precisa de um `base_url` alcançável a partir da VM. Ele consulta
`/health` e `/ready` e exige HTTP 2xx para cada endpoint.

## Release em dev

1. Despache o workflow na branch padrão. O push em `main` também é um gatilho
   para os caminhos configurados nesse workflow.
2. Workflow `Build Image and Update Dev Overlay`:
   - autenticação OIDC da role `AWS_GHA_ROLE_ARN`, build da imagem e push para ECR
   - update de `apps/sample-api/overlays/dev/kustomization.yaml` com nova tag
   - commit da atualização no Git
3. Argo CD faz auto-sync de `workloads-dev`.

## Promoção para stage

Execute o workflow `Promote Image Between Environments` com:

- `source_env=dev`
- `target_env=stage`

O workflow abre PR com bump de tag em stage quando a política do repositório
permite que o token do workflow crie PRs.
Após merge, Argo CD faz auto-sync em stage.

## Promoção para prod

Execute o workflow com:

- `source_env=stage`
- `target_env=prod`

O workflow abre PR com bump de tag em prod.

Controles de produção:

- proteção de GitHub Environment pode exigir aprovação antes de executar workflow
- `workloads-prod` no Argo CD permanece com sync manual
- sync window do AppProject restringe sync ao horário comercial em `America/Sao_Paulo`

## Checklist de verificação após cada promoção

- status da aplicação no Argo em `Healthy/Synced`
- rollout avançou os passos esperados
- nenhum alerta ativo de erro/latência
- dashboards estáveis
- smoke test opcional concluído

