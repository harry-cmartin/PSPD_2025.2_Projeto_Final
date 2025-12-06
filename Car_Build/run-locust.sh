#!/bin/bash

# Script para executar testes de carga com Locust
# Execute a partir do diretório Car_Build

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Locust Load Testing${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Verificar se o Locust está instalado
if [ ! -f "P-Api/venv/bin/locust" ]; then
    echo -e "${RED}❌ Locust não está instalado!${NC}"
    echo -e "${YELLOW}Instale com: cd P-Api && ./venv/bin/pip install locust${NC}"
    exit 1
fi

# Verificar se locustfile.py existe
if [ ! -f "locustfile.py" ]; then
    echo -e "${RED}❌ locustfile.py não encontrado!${NC}"
    exit 1
fi

echo -e "${BLUE}📊 Iniciando Locust...${NC}\n"

echo -e "${YELLOW}Modo de uso:${NC}"
echo -e "  1. Interface Web: Acesse ${GREEN}http://localhost:8089${NC}"
echo -e "  2. Configure o número de usuários e spawn rate"
echo -e "  3. Inicie o teste"
echo -e "  4. Monitore as métricas no Prometheus: ${GREEN}http://localhost:9090${NC}\n"

echo -e "${YELLOW}Tipos de usuário disponíveis:${NC}"
echo -e "  • ${GREEN}CarBuildUser${NC} - Simula usuários normais (recomendado)"
echo -e "  • ${GREEN}HeavyLoadUser${NC} - Testes de stress (use com cautela)\n"

echo -e "${YELLOW}Exemplos de configuração:${NC}"
echo -e "  • Teste leve: 10 usuários, spawn rate 2"
echo -e "  • Teste médio: 50 usuários, spawn rate 5"
echo -e "  • Teste pesado: 100+ usuários, spawn rate 10\n"

# Executar Locust com interface web
P-Api/venv/bin/locust \
    # --host=http://localhost:8000 \
    --web-host=0.0.0.0 \
    --web-port=8089

# Para executar sem interface web (headless), use:
# P-Api/venv/bin/locust \
#     --host=http://localhost:8000 \
#     --users 50 \
#     --spawn-rate 5 \
#     --run-time 60s \
#     --headless \
#     --only-summary
