# Car Build - Cluster Kubernetes Multi-Nó com Kind

Sistema distribuído de catálogo de peças automotivas usando gRPC, Kubernetes, e arquitetura de microserviços.

## Estrutura do Projeto

```
Car_Build/
├── kind-cluster-config.yaml       # Configuração cluster 4 nós (1 control + 3 workers)
├── setup-kind-cluster.sh          # Script automatizado de setup completo
├── cleanup-cluster.sh             # Script de limpeza/remoção do cluster
├── KIND_MIGRATION.md              # Guia completo de migração Minikube→Kind
│
├── manifests/                     # Manifestos Kubernetes (prontos para cluster real)
│   ├── postgres-pvc.yaml
│   ├── postgres-configmap.yaml
│   ├── postgres-deployment.yaml
│   ├── postgres-service.yaml
│   ├── server-a-deployment.yaml
│   ├── server-a-service.yaml
│   ├── server-b-deployment.yaml
│   ├── server-b-service.yaml
│   ├── p-api-deployment.yaml
│   └── p-api-service.yaml
│
├── Microservices/                 # Microserviços gRPC (Node.js)
│   ├── serverA-microsservice/     # Catálogo de peças
│   └── serverB-microsservice/     # Cálculo de preços e checkout
│
├── P-Api/                         # API Gateway (FastAPI/Python)
│   ├── app.py
│   ├── requirements.txt
│   └── generated/                 # Código gerado do protobuf
│
├── protos/                        # Definições Protocol Buffers
│   ├── catalogo.proto
│   ├── pricing.proto
│   └── common.proto
│
└── database/                      # Scripts SQL
    └── init.sql
```

## Novidades - Cluster Real Multi-Nó

### O que mudou do Minikube

| Aspecto             | Minikube (Antes)      | Kind (Agora)                    |
| ------------------- | --------------------- | ------------------------------- |
| **Arquitetura**     | 1 nó único            | 1 control-plane + 3 workers     |
| **Distribuição**    | Simulada              | Real                            |
| **LoadBalancer**    | `minikube tunnel`     | NodePort (padrão K8s)           |
| **Imagens**         | `minikube image load` | Registry local (localhost:5001) |
| **Health Checks**   | Não tinha             | Liveness + Readiness probes     |
| **Resource Limits** | Não tinha             | CPU/Memory requests/limits      |
| **Produção**        | Muito diferente       | Muito similar (AWS EKS, GKE)    |

### Melhorias Implementadas

1. **Cluster Multi-Nó Real**

   - 1 control-plane (gerencia o cluster)
   - 3 workers (executam os pods)
   - Pods distribuídos em diferentes nós

2. **Health Checks**

   - P-API: HTTP GET `/health`
   - Server A/B: TCP socket checks
   - PostgreSQL: `pg_isready` command

3. **Resource Management**

   - Requests e limits de CPU/memória
   - Evita consumo excessivo de recursos
   - Scheduler usa isso para decisões

4. **Registry Local**

   - Docker registry em `localhost:5001`
   - Simula Docker Hub/AWS ECR
   - Imagens distribuídas automaticamente

5. **NodePort Service**
   - Funciona em qualquer cluster Kubernetes
   - Port mapping automático (30080 → 8000)
   - Não depende de ferramentas específicas

## Quick Start (Setup Automatizado)

### Pré-requisitos

```bash
# macOS
brew install kind kubectl docker

# Linux
# Ver KIND_MIGRATION.md para instruções detalhadas
```

### Criar e Rodar o Cluster

```bash
# 1. Entre no diretório
cd Car_Build

# 2. Execute o script (faz tudo automaticamente)
./setup-kind-cluster.sh
```

O script vai:

- Criar registry local (porta 5001)
- Criar cluster Kind (4 nós)
- Build de todas as imagens
- Push para registry local
- Deploy de todos os serviços
- Aguardar tudo ficar pronto

**Aplicação disponível em:** http://localhost:8000

### Verificar Status

```bash
# Ver nós do cluster
kubectl get nodes

# Ver pods e em qual nó estão
kubectl get pods -o wide

# Ver services
kubectl get services

# Logs da P-API
kubectl logs -f deployment/p-api-deployment
```

## Arquitetura

```
┌─────────────┐
│   Browser   │
│             │
└──────┬──────┘
       │ http://localhost:8000
       │
┌──────▼────────────────────────────────────────┐
│           KIND CLUSTER (4 nodes)              │
│                                                │
│  ┌─────────────────────────────────────────┐  │
│  │         Control Plane Node              │  │
│  │  • API Server  • Scheduler  • etcd      │  │
│  └─────────────────────────────────────────┘  │
│                      │                         │
│    ┌─────────────────┼─────────────────┐      │
│    │                 │                 │      │
│  ┌─▼──────┐    ┌────▼─────┐    ┌─────▼──┐   │
│  │Worker 1│    │ Worker 2 │    │Worker 3│   │
│  │        │    │          │    │        │   │
│  │ P-API  │    │Postgres  │    │ServerA │   │
│  │  Pod   │◄──►│   Pod    │◄──►│  Pod   │   │
│  │        │    │          │    │        │   │
│  │        │    │          │    │        │   │
│  │        │    │ServerB   │    │        │   │
│  │        │◄──►│  Pod     │    │        │   │
│  └────────┘    └──────────┘    └────────┘   │
│                                                │
└────────────────────────────────────────────────┘
```

### Fluxo de Comunicação

1. **Cliente Web** → `http://localhost:8000`
2. **NodePort** (30080) → **p-api-service** → **P-API Pod** (Worker 1)
3. **P-API** → gRPC → **server-a-service** → **Server A Pod** (Worker 3)
4. **Server A** → SQL → **postgres-service** → **PostgreSQL Pod** (Worker 2)
5. **P-API** → gRPC → **server-b-service** → **Server B Pod** (qualquer worker)

## Comandos Úteis

```bash
# Ver distribuição dos pods nos nós
kubectl get pods -o wide

# Escalar P-API para ver distribuição
kubectl scale deployment p-api-deployment --replicas=3

# Ver logs em tempo real
kubectl logs -f deployment/p-api-deployment

# Entrar em um pod
kubectl exec -it <pod-name> -- /bin/sh

# Ver eventos do cluster
kubectl get events --sort-by=.metadata.creationTimestamp

# Deletar e recriar um pod (testar self-healing)
kubectl delete pod <pod-name>
kubectl get pods --watch

# Port forward direto (bypass NodePort)
kubectl port-forward service/p-api-service 8000:8000
```

## Limpeza

```bash
# Opção 1: Script automatizado
./cleanup-cluster.sh

# Opção 2: Manual
kubectl delete -f manifests/
kind delete cluster --name car-build-cluster
docker stop kind-registry && docker rm kind-registry
```

## Possiveis problemas

### Pods em ImagePullBackOff

```bash
# Verificar registry
curl http://localhost:5001/v2/_catalog

# Reconectar registry
docker network connect kind kind-registry
```

### Aplicação não responde em localhost:8000

```bash
# Verificar service
kubectl get services

# Verificar pods
kubectl get pods

# Ver logs
kubectl logs -l app=p-api
```

### PostgreSQL não inicializa

```bash
# Ver logs
kubectl logs -l app=postgres

# Verificar PVC
kubectl get pvc

# Descrever pod para ver erros
kubectl describe pod <postgres-pod-name>
```
