#!/bin/bash

# Script de limpeza completa do cluster Kind e registry local
# Remove tudo relacionado ao projeto Car Build

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Car Build - Limpeza Completa${NC}"
echo -e "${YELLOW}=====================================${NC}\n"

echo -e "${YELLOW}Este script irá remover:${NC}"
echo -e "  Cluster Kind 'car-build-cluster'"
echo -e "  Registry Docker 'kind-registry'"
echo -e "  Todos os recursos Kubernetes relacionados\n"

read -p "Deseja continuar? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${GREEN}Operação cancelada.${NC}"
    exit 0
fi

echo -e "${YELLOW}Passo 1: Removendo recursos Kubernetes...${NC}"
if kubectl config current-context | grep -q "kind-car-build-cluster"; then
    kubectl delete -f manifests/ --ignore-not-found=true
    echo -e "${GREEN}Recursos removidos${NC}"
else
    echo -e "${YELLOW}Cluster não está ativo, pulando...${NC}"
fi

echo -e "${YELLOW}Passo 2: Deletando cluster Kind...${NC}"
if kind get clusters | grep -q "car-build-cluster"; then
    kind delete cluster --name car-build-cluster
    echo -e "${GREEN}Cluster deletado${NC}"
else
    echo -e "${YELLOW}Cluster 'car-build-cluster' não encontrado${NC}"
fi

echo -e "${YELLOW}Passo 3: Removendo registry local...${NC}"
if docker ps -a | grep -q "kind-registry"; then
    docker stop kind-registry 2>/dev/null || true
    docker rm kind-registry 2>/dev/null || true
    echo -e "${GREEN}Registry removido${NC}"
else
    echo -e "${YELLOW}Registry 'kind-registry' não encontrado${NC}"
fi

echo -e "${YELLOW}Passo 4: Limpando imagens Docker locais (opcional)...${NC}"
read -p "Deseja remover as imagens Docker do projeto? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    docker rmi localhost:5001/car_build-p-api:latest 2>/dev/null || true
    docker rmi localhost:5001/car_build-server-a:latest 2>/dev/null || true
    docker rmi localhost:5001/car_build-server-b:latest 2>/dev/null || true
    echo -e "${GREEN}Imagens removidas${NC}"
else
    echo -e "${YELLOW}Imagens mantidas${NC}"
fi

echo -e "\n${GREEN}=====================================${NC}"
echo -e "${GREEN}Limpeza concluída!${NC}"
echo -e "${GREEN}=====================================${NC}\n"

echo -e "${YELLOW}Para recriar o cluster:${NC}"
echo -e "  ${GREEN}./setup-kind-cluster.sh${NC}\n"
