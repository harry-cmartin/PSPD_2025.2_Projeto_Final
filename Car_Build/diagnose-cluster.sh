#!/bin/bash

# Script de diagnóstico para troubleshooting do cluster Kind
# Coleta informações úteis para debugar problemas

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}   Car Build - Diagnóstico do Cluster    ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}\n"

# Verificar se kubectl está instalado
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl não está instalado!${NC}"
    exit 1
fi

# Verificar se Kind está instalado
if ! command -v kind &> /dev/null; then
    echo -e "${RED}Kind não está instalado!${NC}"
    exit 1
fi

# Verificar se Docker está rodando
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker não está rodando!${NC}"
    exit 1
fi

echo -e "${GREEN}Ferramentas básicas instaladas${NC}\n"

# 1. Clusters Kind
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}1. Clusters Kind${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kind get clusters
echo ""

# 2. Contexto kubectl
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}2. Contexto kubectl atual${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kubectl config current-context
echo ""

# 3. Nós do cluster
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}3. Nós do Cluster${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kubectl get nodes
echo ""

# 4. Status dos nós (detalhado)
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}4. Status Detalhado dos Nós${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
for node in $(kubectl get nodes -o name); do
    echo -e "${BLUE}Nó: $node${NC}"
    kubectl describe $node | grep -A 5 "Conditions:"
    echo ""
done

# 5. Registry local
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}5. Registry Local${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if docker ps | grep -q kind-registry; then
    echo -e "${GREEN}Registry rodando${NC}"
    echo -e "\nImagens no registry:"
    curl -s http://localhost:5001/v2/_catalog | jq . || echo "Erro ao listar imagens"
else
    echo -e "${RED}Registry NÃO está rodando${NC}"
fi
echo ""

# 6. Deployments
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}6. Deployments${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kubectl get deployments
echo ""

# 7. Pods (com localização)
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}7. Pods (com localização no nó)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kubectl get pods -o wide
echo ""

# 8. Pods com problemas
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}8. Pods com Problemas${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
PROBLEM_PODS=$(kubectl get pods --field-selector=status.phase!=Running,status.phase!=Succeeded -o name 2>/dev/null)
if [ -z "$PROBLEM_PODS" ]; then
    echo -e "${GREEN}Nenhum pod com problema${NC}"
else
    echo -e "${RED}Pods com problema:${NC}"
    kubectl get pods --field-selector=status.phase!=Running,status.phase!=Succeeded
    echo ""
    for pod in $PROBLEM_PODS; do
        echo -e "${RED}Detalhes de $pod:${NC}"
        kubectl describe $pod | grep -A 20 "Events:"
        echo ""
    done
fi
echo ""

# 9. Services
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}9. Services${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kubectl get services
echo ""

# 10. Endpoints (conexões service -> pod)
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}10. Endpoints (Service -> Pod)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kubectl get endpoints
echo ""

# 11. PVC e Storage
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}11. Persistent Volume Claims${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kubectl get pvc
echo ""

# 12. ConfigMaps
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}12. ConfigMaps${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kubectl get configmaps
echo ""

# 13. Últimos eventos
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}13. Últimos 20 Eventos do Cluster${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
kubectl get events --sort-by=.metadata.creationTimestamp | tail -20
echo ""

# 14. Logs resumidos de cada deployment
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}14. Últimas 10 Linhas de Logs${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

for deployment in $(kubectl get deployments -o name); do
    echo -e "${BLUE}Logs de $deployment:${NC}"
    kubectl logs $deployment --tail=10 2>/dev/null || echo "  (Sem logs ou pods não rodando)"
    echo ""
done

# 15. Teste de conectividade P-API
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}15. Teste de Conectividade P-API${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Testando http://localhost:8000/health ..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}P-API respondendo corretamente (HTTP $HTTP_CODE)${NC}"
    curl -s http://localhost:8000/health | jq . || echo ""
else
    echo -e "${RED}P-API não responde (HTTP $HTTP_CODE)${NC}"
    echo -e "${YELLOW}Verifique:${NC}"
    echo -e "  kubectl get pods -l app=p-api"
    echo -e "  kubectl logs deployment/p-api-deployment"
    echo -e "  kubectl describe service/p-api-service"
fi
echo ""

# 16. Containers Docker do Kind
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}16. Containers Docker do Kind${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
docker ps --filter "name=car-build-cluster"
echo ""

# 17. Uso de recursos (se metrics-server estiver instalado)
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}17. Uso de Recursos (se disponível)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if kubectl top nodes 2>/dev/null; then
    echo ""
    kubectl top pods 2>/dev/null || echo "Metrics não disponíveis"
else
    echo -e "${YELLOW}Metrics-server não instalado${NC}"
    echo -e "Para instalar: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
fi
echo ""

# 18. Resumo e Recomendações
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}   Resumo e Recomendações                ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}\n"

# Contar pods
TOTAL_PODS=$(kubectl get pods --no-headers 2>/dev/null | wc -l)
RUNNING_PODS=$(kubectl get pods --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
PROBLEM_PODS_COUNT=$(kubectl get pods --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)

echo -e "${BLUE}Estatísticas:${NC}"
echo -e "  Total de pods: $TOTAL_PODS"
echo -e "  Pods rodando: ${GREEN}$RUNNING_PODS${NC}"
echo -e "  Pods com problema: ${RED}$PROBLEM_PODS_COUNT${NC}"
echo ""

if [ "$PROBLEM_PODS_COUNT" -eq 0 ] && [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}CLUSTER SAUDÁVEL!${NC}"
    echo -e "Aplicação disponível em: ${GREEN}http://localhost:8000${NC}"
else
    echo -e "${RED}PROBLEMAS DETECTADOS${NC}"
    echo ""
    echo -e "${YELLOW}Comandos úteis para debug:${NC}"
    echo -e "  Ver logs: ${GREEN}kubectl logs -l app=p-api --tail=50${NC}"
    echo -e "  Descrever pod: ${GREEN}kubectl describe pod <pod-name>${NC}"
    echo -e "  Ver eventos: ${GREEN}kubectl get events --sort-by=.metadata.creationTimestamp${NC}"
    echo -e "  Entrar no pod: ${GREEN}kubectl exec -it <pod-name> -- /bin/sh${NC}"
    echo -e "  Reiniciar deployment: ${GREEN}kubectl rollout restart deployment/<deployment-name>${NC}"
fi

echo ""
echo -e "${YELLOW}Documentação completa:${NC}"
echo -e "  ${GREEN}KIND_MIGRATION.md${NC} - Guia completo"
echo -e "  ${GREEN}COMMANDS_CHEATSHEET.md${NC} - Comandos úteis"
echo -e "  ${GREEN}./cleanup-cluster.sh${NC} - Remover e recriar cluster"
echo ""
