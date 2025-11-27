#!/bin/bash

# Script de setup do cluster Kind multi-nó para o projeto Car Build
# Este script automatiza a criação do cluster, registry local, e deploy da aplicação

set -e  # Para em caso de erro

# Define versão da API do Docker para compatibilidade
export DOCKER_API_VERSION=1.43

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Car Build - Setup Cluster Kind${NC}"
echo -e "${GREEN}=====================================${NC}\n"

# Verifica se Kind está instalado
if ! command -v kind &> /dev/null; then
    echo -e "${RED}Kind não está instalado!${NC}"
    echo -e "${YELLOW}Instale com: brew install kind${NC}"
    exit 1
fi

# Verifica se kubectl está instalado
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl não está instalado!${NC}"
    echo -e "${YELLOW}Instale com: brew install kubectl${NC}"
    exit 1
fi

# Verifica se Docker está rodando
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker não está rodando!${NC}"
    echo -e "${YELLOW}Inicie o Docker Desktop e tente novamente.${NC}"
    exit 1
fi

echo -e "${YELLOW}Passo 1: Criando registry local para imagens Docker...${NC}"

# Cria registry local (se não existir)
if [ "$(docker ps -q -f name=kind-registry)" ]; then
    echo -e "${GREEN}Registry local já existe${NC}"
else
    docker run -d --restart=always -p 5001:5000 --name kind-registry registry:2
    echo -e "${GREEN}Registry local criado na porta 5001${NC}"
fi

echo -e "${YELLOW}Passo 2: Criando cluster Kind multi-nó...${NC}"

# Remove cluster anterior se existir
if kind get clusters | grep -q "car-build-cluster"; then
    echo -e "${YELLOW}Removendo cluster anterior...${NC}"
    kind delete cluster --name car-build-cluster
fi

# Cria cluster com configuração multi-nó
kind create cluster --config kind-cluster-config.yaml

# Conecta o registry ao network do kind
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' kind-registry)" = 'null' ]; then
    docker network connect kind kind-registry
fi

# Documenta o registry local no cluster
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:5001"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo -e "${GREEN}Cluster criado com sucesso!${NC}"
echo -e "${GREEN}  - 1 control-plane node${NC}"
echo -e "${GREEN}  - 3 worker nodes${NC}"

echo -e "${YELLOW}Passo 3: Verificando nós do cluster...${NC}"
kubectl get nodes

echo -e "${YELLOW}Passo 4: Construindo imagens Docker...${NC}"

# Build das imagens com tag para registry local
echo -e "${YELLOW}  Construindo Server A...${NC}"
docker build -f ./Microservices/serverA-microsservice/Dockerfile \
    -t localhost:5001/car_build-server-a:latest .

echo -e "${YELLOW}  Construindo Server B...${NC}"
docker build -f ./Microservices/serverB-microsservice/Dockerfile \
    -t localhost:5001/car_build-server-b:latest .

echo -e "${YELLOW}  Construindo P-API...${NC}"
docker build -f ./P-Api/Dockerfile \
    -t localhost:5001/car_build-p-api:latest ./P-Api

echo -e "${GREEN}Imagens construídas com sucesso!${NC}"

echo -e "${YELLOW}Passo 5: Enviando imagens para registry local...${NC}"
docker push localhost:5001/car_build-server-a:latest
docker push localhost:5001/car_build-server-b:latest
docker push localhost:5001/car_build-p-api:latest
echo -e "${GREEN}Imagens enviadas para registry!${NC}"

echo -e "${YELLOW}Passo 6: Carregando imagens nos nós do cluster...${NC}"
kind load docker-image localhost:5001/car_build-server-a:latest --name car-build-cluster
kind load docker-image localhost:5001/car_build-server-b:latest --name car-build-cluster
kind load docker-image localhost:5001/car_build-p-api:latest --name car-build-cluster
echo -e "${GREEN}Imagens carregadas nos nós!${NC}"

echo -e "${YELLOW}Passo 7: Aplicando manifestos Kubernetes...${NC}"
kubectl apply -f manifests/

echo -e "${YELLOW}Aguardando deployments ficarem prontos...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment --all

echo -e "\n${GREEN}=====================================${NC}"
echo -e "${GREEN}Setup concluído com sucesso!${NC}"
echo -e "${GREEN}=====================================${NC}\n"

echo -e "${YELLOW}Status dos recursos:${NC}"
echo -e "\n${YELLOW}Deployments:${NC}"
kubectl get deployments

echo -e "\n${YELLOW}Pods:${NC}"
kubectl get pods

echo -e "\n${YELLOW}Services:${NC}"
kubectl get services

echo -e "\n${GREEN}=====================================${NC}"
echo -e "${GREEN}Aplicação disponível em:${NC}"
echo -e "${GREEN}   http://localhost:8000${NC}"
echo -e "${GREEN}=====================================${NC}\n"

echo -e "${YELLOW}Comandos úteis:${NC}"
echo -e "  Ver logs: ${GREEN}kubectl logs -f deployment/p-api-deployment${NC}"
echo -e "  Ver pods: ${GREEN}kubectl get pods -o wide${NC}"
echo -e "  Deletar cluster: ${GREEN}kind delete cluster --name car-build-cluster${NC}"
echo -e "  Dashboard: ${GREEN}kubectl proxy${NC} (e acesse via browser)\n"
