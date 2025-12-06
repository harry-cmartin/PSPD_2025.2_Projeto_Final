#!/bin/bash

# Script para iniciar todos os serviços com monitoramento Prometheus
# Este script inicia seus microserviços e o Prometheus para coletar métricas

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detectar diretório atual
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Procurar por diretórios do Prometheus no projeto
PROMETHEUS_DIR=$(find "$PROJECT_ROOT" -maxdepth 1 -type d -name "prometheus-*" 2>/dev/null | head -1)

# Se não encontrou, verificar se usuário definiu variável de ambiente
if [ -z "$PROMETHEUS_DIR" ] && [ -n "$PROMETHEUS_HOME" ]; then
    PROMETHEUS_DIR="$PROMETHEUS_HOME"
fi

# Função para verificar se uma porta está em uso
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        return 0
    else
        return 1
    fi
}

# Verificar se o Prometheus existe
if [ -z "$PROMETHEUS_DIR" ] || [ ! -f "$PROMETHEUS_DIR/prometheus" ]; then
    echo -e "${RED}❌ Prometheus não encontrado!${NC}"
    echo -e "${YELLOW}Por favor, baixe e extraia o Prometheus no diretório do projeto:${NC}"
    echo -e "${YELLOW}   cd $PROJECT_ROOT${NC}"
    echo -e "${YELLOW}   wget https://github.com/prometheus/prometheus/releases/download/v3.7.3/prometheus-3.7.3.linux-amd64.tar.gz${NC}"
    echo -e "${YELLOW}   tar xvfz prometheus-3.7.3.linux-amd64.tar.gz${NC}"
    echo -e "${YELLOW}${NC}"
    echo -e "${YELLOW}Ou defina a variável de ambiente:${NC}"
    echo -e "${YELLOW}   export PROMETHEUS_HOME=/caminho/para/prometheus${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prometheus encontrado em: $PROMETHEUS_DIR${NC}"

echo -e "${BLUE}📊 Verificando dependências...${NC}"

# Verificar se as dependências dos microserviços estão instaladas
if [ ! -d "$SCRIPT_DIR/Microservices/node_modules" ]; then
    echo -e "${YELLOW}⚙️  Instalando dependências dos microserviços Node.js...${NC}"
    cd "$SCRIPT_DIR/Microservices"
    npm install
    cd "$SCRIPT_DIR"
fi

# Verificar se as dependências do P-API estão instaladas
if [ ! -d "$SCRIPT_DIR/P-Api/venv" ]; then
    echo -e "${YELLOW}⚙️  Criando ambiente virtual Python para P-API...${NC}"
    cd "$SCRIPT_DIR/P-Api"
    python3 -m venv venv
    ./venv/bin/pip install -r requirements.txt
    cd "$SCRIPT_DIR"
fi

echo -e "\n${GREEN}✅ Dependências verificadas${NC}\n"

# Iniciar Prometheus
echo -e "${BLUE}🚀 Iniciando Prometheus...${NC}"
cd "$PROMETHEUS_DIR"
./prometheus --config.file=prometheus.yml > /tmp/prometheus.log 2>&1 &
PROMETHEUS_PID=$!
cd - > /dev/null

sleep 2

if ps -p $PROMETHEUS_PID > /dev/null; then
    echo -e "${GREEN}✅ Prometheus rodando (PID: $PROMETHEUS_PID)${NC}"
    echo -e "${GREEN}   Interface Web: ${BLUE}http://localhost:9090${NC}"
else
    echo -e "${RED}❌ Falha ao iniciar Prometheus${NC}"
    cat /tmp/prometheus.log
    exit 1
fi

echo -e "\n${YELLOW}⏳ Aguardando 3 segundos antes de configurar port-forwards...${NC}\n"
sleep 3

# Configurar port-forwards para Server A e Server B

# Verificar se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl não encontrado! Port-forwards não serão configurados.${NC}"
    echo -e "${YELLOW}  Certifique-se de que o cluster Kubernetes está rodando se precisar das métricas dos Servers A e B${NC}"
else
    # Verificar se o cluster está rodando
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}❌ Cluster Kubernetes não está rodando!${NC}"
        echo -e "${YELLOW}   Port-forwards não serão configurados. Execute ./setup-kind-cluster.sh se necessário${NC}"
    else
        echo -e "${BLUE}🔍 Verificando pods...${NC}"
        
        # Verificar se os pods estão rodando
        SERVER_A_RUNNING=$(kubectl get pods 2>/dev/null | grep -c "server-a" || echo "0")
        SERVER_B_RUNNING=$(kubectl get pods 2>/dev/null | grep -c "server-b" || echo "0")
        
        if [ "$SERVER_A_RUNNING" -eq "0" ] || [ "$SERVER_B_RUNNING" -eq "0" ]; then
            echo -e "${YELLOW}⚠️  Alguns pods não estão rodando. Port-forwards podem falhar.${NC}"
        fi
        
        # Parar port-forwards antigos se existirem
        echo -e "${YELLOW}🧹 Limpando port-forwards antigos...${NC}"
        pkill -f "kubectl port-forward.*server-a" 2>/dev/null || true
        pkill -f "kubectl port-forward.*server-b" 2>/dev/null || true
        sleep 1
        
        # Iniciar port-forward para Server A (métricas na porta 9091)
        if [ "$SERVER_A_RUNNING" -gt "0" ]; then
            echo -e "${BLUE}🔀 Iniciando port-forward Server A (9091)...${NC}"
            kubectl port-forward deployment/server-a-deployment 9091:9091 > /tmp/port-forward-server-a.log 2>&1 &
            SERVER_A_PID=$!
            sleep 2
            
            if curl -s http://localhost:9091/metrics > /dev/null 2>&1; then
                echo -e "${GREEN}✅ Server A métricas disponíveis (PID: $SERVER_A_PID)${NC}"
            else
                echo -e "${YELLOW}⚠️  Server A port-forward iniciado mas métricas ainda não acessíveis${NC}"
            fi
        fi
        
        # Iniciar port-forward para Server B (métricas na porta 9092)
        if [ "$SERVER_B_RUNNING" -gt "0" ]; then
            echo -e "${BLUE}🔀 Iniciando port-forward Server B (9092)...${NC}"
            kubectl port-forward deployment/server-b-deployment 9092:9092 > /tmp/port-forward-server-b.log 2>&1 &
            SERVER_B_PID=$!
            sleep 2
            
            if curl -s http://localhost:9092/metrics > /dev/null 2>&1; then
                echo -e "${GREEN}✅ Server B métricas disponíveis (PID: $SERVER_B_PID)${NC}"
            else
                echo -e "${YELLOW}⚠️  Server B port-forward iniciado mas métricas ainda não acessíveis${NC}"
            fi
        fi
    fi
fi

# Mensagem de sucesso
echo -e "${GREEN}   ✅ Prometheus Configurado!${NC}"

echo -e "${BLUE}📍 URLs de Acesso:${NC}"
echo -e "   ${GREEN}Prometheus Web UI:${NC}    http://localhost:9090"
echo -e "   ${GREEN}P-API:${NC}                http://localhost:8000"
echo -e "   ${GREEN}Server A Metrics:${NC}     http://localhost:9091/metrics"
echo -e "   ${GREEN}Server B Metrics:${NC}     http://localhost:9092/metrics"

echo -e "\n${YELLOW}📝 Serviços ativos:${NC}"
echo -e "   Prometheus (PID: $PROMETHEUS_PID)"
if [ -n "$SERVER_A_PID" ]; then
    echo -e "   Port-forward Server A (PID: $SERVER_A_PID)"
fi
if [ -n "$SERVER_B_PID" ]; then
    echo -e "   Port-forward Server B (PID: $SERVER_B_PID)"
fi

echo -e "\n${YELLOW}💡 Dicas:${NC}"
echo -e "   • Acesse o Prometheus em http://localhost:9090"
echo -e "   • Veja as métricas na aba 'Graph' ou 'Status > Targets'"
echo -e "   • Execute './test-prometheus.sh' para testar todos os endpoints"

echo -e "\n${YELLOW}🛑 Para parar os serviços:${NC}"
echo -e "   Pressione Ctrl+C"
echo -e "   ${GREEN}ou em outro terminal:${NC}"
if [ -n "$SERVER_A_PID" ] && [ -n "$SERVER_B_PID" ]; then
    echo -e "   kill $PROMETHEUS_PID $SERVER_A_PID $SERVER_B_PID"
else
    echo -e "   kill $PROMETHEUS_PID"
fi

echo -e "\n${BLUE}📊 Métricas disponíveis:${NC}"
echo -e "   • ${GREEN}p_api_requests_total${NC} - Total de requisições na API"
echo -e "   • ${GREEN}p_api_request_duration_seconds${NC} - Latência das requisições"
echo -e "   • ${GREEN}server_a_grpc_requests_total${NC} - Requisições gRPC Server A"
echo -e "   • ${GREEN}server_a_db_queries_total${NC} - Queries no banco de dados"
echo -e "   • ${GREEN}server_b_compras_processadas_total${NC} - Total de compras"
echo -e "   • ${GREEN}server_b_valor_total_compras_reais${NC} - Valor total vendido"

echo -e "\n${GREEN}✨ Sistema de monitoramento ativo! Mantenha este terminal aberto.${NC}\n"

# Configurar trap para limpar processos ao sair
cleanup() {
    echo -e "\n${YELLOW}🛑 Parando serviços...${NC}"
    kill $PROMETHEUS_PID 2>/dev/null || true
    if [ -n "$SERVER_A_PID" ]; then
        kill $SERVER_A_PID 2>/dev/null || true
    fi
    if [ -n "$SERVER_B_PID" ]; then
        kill $SERVER_B_PID 2>/dev/null || true
    fi
    echo -e "${GREEN}✅ Serviços parados${NC}"
    exit 0
}

trap cleanup INT TERM

# Monitorar processos e manter o script rodando
echo -e "${BLUE}🔍 Monitorando processos... (Ctrl+C para parar tudo)${NC}\n"

while true; do
    # Verificar se Prometheus ainda está rodando
    if ! ps -p $PROMETHEUS_PID > /dev/null 2>&1; then
        echo -e "${RED}❌ Prometheus parou inesperadamente!${NC}"
        echo -e "${YELLOW}Logs em /tmp/prometheus.log${NC}"
        cleanup
    fi
    
    # Reiniciar port-forwards se caírem
    if [ -n "$SERVER_A_PID" ] && ! ps -p $SERVER_A_PID > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Port-forward Server A caiu. Reiniciando...${NC}"
        kubectl port-forward deployment/server-a-deployment 9091:9091 > /tmp/port-forward-server-a.log 2>&1 &
        SERVER_A_PID=$!
    fi
    
    if [ -n "$SERVER_B_PID" ] && ! ps -p $SERVER_B_PID > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Port-forward Server B caiu. Reiniciando...${NC}"
        kubectl port-forward deployment/server-b-deployment 9092:9092 > /tmp/port-forward-server-b.log 2>&1 &
        SERVER_B_PID=$!
    fi
    
    sleep 10
done
