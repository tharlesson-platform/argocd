# Validação local gratuita do sample-api

Os workflows de build, promoção e smoke agora validam o projeto em VMs
locais efêmeras. Não utilizam AWS/ECR, OIDC, secrets de nuvem, runner
hospedado nem licenças pagas. A imagem é construída para Linux ARM64.

O build usa Podman rootless, registry público Distribution fixado por digest,
publicado exclusivamente em `127.0.0.1` da VM, e realiza push seguido de
remoção da imagem local e pull pelo digest. HTTP sem TLS é permitido apenas
nesse loopback descartável, sem dados ou credenciais de produção; não há
configuração de registry inseguro global. Nenhum serviço da máquina do
usuário é substituído. O registry e a imagem não são uma entrega persistente:
são eliminados junto com a VM após a validação. SHA, digest, hashes do OCI e
do relatório de scanner ficam no log, junto do resultado dos probes.

A imagem pública Wolfi fixada por digest utiliza Python 3.12, dependências
de runtime separadas das de teste, usuário 10001, rootfs somente leitura e
capabilities removidas na execução. Trivy fixado e verificado por SHA256
consulta sua base atual e exige zero vulnerabilidades conhecidas de qualquer
severidade, com inventários de OS e Python presentes e nenhum ignore.
Os pacotes APK são atualizados no build; transitivas Python são resolvidas e
auditadas no conteúdo real da imagem. Isso não substitui monitoramento
contínuo após a execução nem garante ausência de vulnerabilidades inéditas.

O formato OCI do Podman não conserva a extensão Docker HEALTHCHECK. O gate
configura o healthcheck no container e exige sua execução bem-sucedida, além
dos probes HTTP e da verificação de UID 10001.

O smoke inicia a API real em loopback e valida `/`, `/health`, `/ready` e
`/metrics`, incluindo a versão correspondente ao SHA do código. O fluxo de
promoção **apenas simula** `dev -> stage` e `stage -> prod`: utiliza o mesmo
script de atualização de tag, mas em uma cópia temporária, renderiza com
Kustomize, valida schemas conhecidos com kubeconform e confirma que os
arquivos versionados permaneceram idênticos. CRDs sem schema permanecem
explicitamente fora da validação kubeconform, como no CI existente.

Não há `kubectl apply`, `terraform apply`, push de Git, alteração do overlay
versionado, criação de PR de ambiente ou promoção real. Os nomes e caminhos
dos workflows são preservados para manter histórico. A funcionalidade antiga
de publicação ECR e promoção real foi substituída pela validação local; uma
promoção real futura exige implementação e autorização próprias.

## Operação

A validação injeta somente na cópia temporária a configuração de imagem do
CRD Rollout, que o Kustomize não conhece por padrão, e uma definição OpenAPI
local para mesclar containers por nome. Sem essa definição, os patches
estratégicos substituem a lista de containers e removem campos como image.
A correção do motor de renderização é aplicada somente à simulação; não
qualifica a configuração atual de um cluster real. Os manifests GitOps
versionados não são modificados; o resultado é uma simulação local.

O controlador deve verificar repositório, workflow, evento, run/attempt,
SHA/blob e base da PR antes de registrar o runner com rótulo exclusivo
`argocd-run-<run_id>`. O runner pertence somente ao repositório e usa uma VM
sem mounts/credenciais do host, rede privada bloqueada e usuário sem sudo.
O build exige Podman rootless provisionado pelo controlador. Depois de cada
job, o controlador confirma o resultado e remove a VM e o runner efêmero.
Nenhum outro job ativo deve ser interrompido ou duplicado.

Os gates existentes de lint, testes, Terraform e manifests são preservados.
A revisão independente e a revalidação de head/base e checks são obrigatórias
antes do merge. Não se habilita plano pago para adicionar proteção de branch.

## Reversão

Reverter a PR restaura os workflows anteriores e a dependência de AWS; não
executa publicação nem promoção automaticamente. Não houve alteração em
produção, estado Terraform ou overlays versionados nesta migração.
