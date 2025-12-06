#!/bin/bash

# Script de teste rápido para validar o Prometheus
# Execute este script DEPOIS de iniciar seus serviços

echo "🧪 Teste Rápido do Prometheus"
echo "=============================="
echo ""

# Verificar se Prometheus está rodando
echo "1️⃣ Verificando Prometheus..."
if curl -s http://localhost:9090/-/healthy > /dev/null; then
    echo "✅ Prometheus está rodando"
else
    echo "❌ Prometheus NÃO está rodando"
    echo "   Execute: ./start-with-prometheus.sh"
    exit 1
fi

echo ""
echo "2️⃣ Verificando endpoints de métricas..."

# Verificar P-API
if curl -s http://localhost:8000/metrics > /dev/null 2>&1; then
    echo "✅ P-API metrics disponíveis (porta 8000)"
else
    echo "⚠️  P-API não está respondendo"
fi

# Verificar Server A
if curl -s http://localhost:9091/metrics > /dev/null 2>&1; then
    echo "✅ Server A metrics disponíveis (porta 9091)"
else
    echo "⚠️  Server A não está respondendo"
fi

# Verificar Server B
if curl -s http://localhost:9092/metrics > /dev/null 2>&1; then
    echo "✅ Server B metrics disponíveis (porta 9092)"
else
    echo "⚠️  Server B não está respondendo"
fi

echo ""
echo "3️⃣ Fazendo requisições de teste..."

# Fazer algumas requisições para gerar métricas
for i in {1..10}; do
    curl -s http://localhost:8000/health > /dev/null 2>&1
done

echo "✅ 10 requisições enviadas para /health"

echo ""
echo "4️⃣ Consultando métricas do Prometheus..."

# Query simples via API do Prometheus
METRICS=$(curl -s 'http://localhost:9090/api/v1/query?query=p_api_requests_total' | grep -o '"value":\[[^]]*\]' | tail -1)

if [ -n "$METRICS" ]; then
    echo "✅ Métricas sendo coletadas!"
    echo "   Dados: $METRICS"
else
    echo "⚠️  Aguarde alguns segundos para o Prometheus coletar dados..."
fi

echo ""
echo "=============================="
echo "✨ Teste concluído!"
echo ""
echo "🌐 Acesse o Prometheus em:"
echo "   http://localhost:9090"
echo ""
echo "📊 Queries para testar:"
echo "   p_api_requests_total"
echo "   rate(p_api_requests_total[1m])"
echo "   p_api_active_requests"
echo ""
