# 📊 Guia Completo do Prometheus - Car Build

## 🎯 O que foi configurado?

O Prometheus é um sistema de **monitoramento e alerta** que coleta métricas dos seus serviços a cada 10 segundos. Pense nele como um "painel de controle" que mostra o que está acontecendo na sua aplicação em tempo real.

### ✅ Serviços Monitorados:

1. **P-API (Gateway FastAPI)** - porta 8000
   - Total de requisições HTTP
   - Latência (tempo de resposta)
   - Requisições ativas
   - Chamadas gRPC para outros serviços

2. **Server A (Catálogo)** - porta gRPC 50051, métricas 9091
   - Requisições gRPC
   - Queries no PostgreSQL
   - Conexões ativas com banco
   - Tempo de resposta das queries

3. **Server B (Pricing)** - porta gRPC 50052, métricas 9092
   - Cálculos de orçamento
   - Compras processadas
   - Valor total vendido
   - Tempo de processamento

---

## 🚀 Como Usar

### 1️⃣ Iniciar o Prometheus

```bash
cd /home/dutra/codigos/PSPD_2025.2_Projeto_Final/Car_Build
./start-with-prometheus.sh
```

Isso iniciará o Prometheus. Ele ficará rodando e coletando métricas automaticamente.

### 2️⃣ Iniciar seus serviços

Em outro terminal, inicie seus serviços normalmente:

```bash
# Se estiver usando Docker Compose
cd Car_Build
docker-compose up

# OU se estiver usando Kind
./setup-kind-cluster.sh

# OU manualmente (cada um em um terminal separado)
# Terminal 1 - P-API
cd Car_Build/P-Api
source venv/bin/activate
uvicorn app:app --host 0.0.0.0 --port 8000

# Terminal 2 - Server A
cd Car_Build/Microservices/serverA-microsservice
node index.js

# Terminal 3 - Server B
cd Car_Build/Microservices/serverB-microsservice
node index.js

# Terminal 4 - Frontend
cd Car_Build/WebClient
npm start
```

### 3️⃣ Acessar o Prometheus

Abra no navegador: **http://localhost:9090**

---

## 📈 Como Ver as Métricas

### Interface do Prometheus

1. **Targets (Status > Targets)**
   - Mostra quais serviços estão sendo monitorados
   - Verde = serviço respondendo ✅
   - Vermelho = serviço com problema ❌

2. **Graph (Menu principal)**
   - Digite queries para visualizar métricas
   - Pode ver em gráfico ou tabela

---

## 🔍 Queries Úteis para Testes de Carga

### 📊 **Métricas de Requisições HTTP (P-API)**

```promql
# Total de requisições por segundo
rate(p_api_requests_total[1m])

# Requisições por endpoint
sum by (endpoint) (p_api_requests_total)

# Taxa de erro (requisições com status 500)
sum(rate(p_api_requests_total{status="500"}[1m]))

# Requisições ativas no momento
p_api_active_requests

# Latência média por endpoint (em segundos)
rate(p_api_request_duration_seconds_sum[1m]) / rate(p_api_request_duration_seconds_count[1m])

# Percentil 95 da latência (95% das requisições são mais rápidas que isso)
histogram_quantile(0.95, rate(p_api_request_duration_seconds_bucket[5m]))

# Percentil 99 da latência (apenas 1% das requisições são mais lentas)
histogram_quantile(0.99, rate(p_api_request_duration_seconds_bucket[5m]))
```

### 🗄️ **Métricas do Banco de Dados (Server A)**

```promql
# Total de queries por segundo
rate(server_a_db_queries_total[1m])

# Taxa de erro em queries
sum(rate(server_a_db_queries_total{status="error"}[1m]))

# Conexões ativas com o banco
server_a_db_connections_active

# Tempo médio de query
rate(server_a_db_query_duration_seconds_sum[1m]) / rate(server_a_db_query_duration_seconds_count[1m])
```

### 🎯 **Métricas gRPC (Server A e B)**

```promql
# Requisições gRPC por segundo no Server A
rate(server_a_grpc_requests_total[1m])

# Requisições gRPC por segundo no Server B
rate(server_b_grpc_requests_total[1m])

# Taxa de sucesso Server A (%)
sum(rate(server_a_grpc_requests_total{status="success"}[1m])) / sum(rate(server_a_grpc_requests_total[1m])) * 100

# Latência média gRPC Server A
rate(server_a_grpc_request_duration_seconds_sum[1m]) / rate(server_a_grpc_request_duration_seconds_count[1m])
```

### 💰 **Métricas de Negócio (Server B)**

```promql
# Total de cálculos de orçamento
server_b_calculos_realizados_total

# Total de compras processadas
server_b_compras_processadas_total

# Valor total em vendas (R$)
server_b_valor_total_compras_reais

# Compras por minuto
rate(server_b_compras_processadas_total[1m]) * 60

# Ticket médio (valor médio por compra)
server_b_valor_total_compras_reais / server_b_compras_processadas_total{status="CONFIRMADO"}
```

### 💻 **Métricas de Sistema (CPU, Memória)**

```promql
# Uso de CPU por processo (%)
rate(process_cpu_seconds_total[1m]) * 100

# Uso de memória (MB)
process_resident_memory_bytes / 1024 / 1024

# Memória usada pelo Server A
process_resident_memory_bytes{job="server-a"} / 1024 / 1024
```

---

## 🧪 Fazendo Testes de Carga

### Preparação

1. **Inicie o Prometheus**: `./start-with-prometheus.sh`
2. **Inicie todos os serviços** (P-API, Server A, Server B, Frontend)
3. **Acesse o Prometheus**: http://localhost:9090
4. **Abra o frontend**: http://localhost:3000

### Ferramentas para Testes de Carga

#### 🔹 Opção 1: Apache Bench (ab)

```bash
# Instalar
sudo apt install apache2-utils

# Teste simples - 1000 requisições, 10 concorrentes
ab -n 1000 -c 10 http://localhost:8000/health

# Teste com POST (ajuste o JSON conforme seu endpoint)
ab -n 500 -c 20 -p payload.json -T application/json http://localhost:8000/get-pecas
```

#### 🔹 Opção 2: wrk (mais poderoso)

```bash
# Instalar
sudo apt install wrk

# Teste durante 30 segundos, 10 threads, 100 conexões
wrk -t10 -c100 -d30s http://localhost:8000/health

# Teste com script Lua para POST
wrk -t10 -c50 -d60s -s post.lua http://localhost:8000/get-pecas
```

#### 🔹 Opção 3: k6 (recomendado para testes complexos)

```bash
# Instalar
sudo snap install k6

# Criar script de teste (test.js)
cat > test.js << 'EOF'
import http from 'k6/http';
import { sleep } from 'k6';

export let options = {
  vus: 10, // 10 usuários virtuais
  duration: '30s', // duração do teste
};

export default function () {
  http.get('http://localhost:8000/health');
  sleep(1);
}
EOF

# Executar teste
k6 run test.js
```

### Durante o Teste

**No Prometheus**, monitore em tempo real:

```promql
# Requisições por segundo
rate(p_api_requests_total[10s])

# Latência P99 (99% das requisições)
histogram_quantile(0.99, rate(p_api_request_duration_seconds_bucket[1m]))

# Erros por segundo
rate(p_api_requests_total{status=~"5.."}[10s])
```

---

## 📊 Exemplo de Teste Completo

### Cenário: Teste de Carga no Endpoint de Peças

```bash
# 1. Preparar payload
cat > get-pecas.json << 'EOF'
{
  "modelo": "civic",
  "ano": 2020
}
EOF

# 2. Executar teste com curl em loop (simples)
for i in {1..100}; do
  curl -X POST http://localhost:8000/get-pecas \
    -H "Content-Type: application/json" \
    -d @get-pecas.json &
done

# 3. No Prometheus, execute estas queries:
```

**Queries para analisar durante o teste:**

```promql
# 1. Taxa de requisições
rate(p_api_requests_total{endpoint="/get-pecas"}[30s])

# 2. Latência P95
histogram_quantile(0.95, rate(p_api_request_duration_seconds_bucket{endpoint="/get-pecas"}[1m]))

# 3. Queries no banco (Server A)
rate(server_a_db_queries_total[30s])

# 4. Requisições gRPC do P-API para Server A
rate(p_api_grpc_calls_total{service="server-a"}[30s])
```

---

## 🎯 Métricas Importantes para Analisar

### Durante Testes de Carga

| Métrica | O que observar | Valores bons |
|---------|----------------|--------------|
| **Latência P95** | 95% das requisições | < 200ms |
| **Latência P99** | 99% das requisições | < 500ms |
| **Taxa de Erro** | Requisições 5xx | < 1% |
| **Throughput** | Req/segundo | Depende do hardware |
| **Conexões DB** | Pool do PostgreSQL | < 20 (seu max) |
| **Requisições Ativas** | Concorrência | Não deve crescer indefinidamente |

---

## 🔧 Troubleshooting

### Prometheus não está coletando métricas

```bash
# Verificar se os serviços estão expondo /metrics
curl http://localhost:8000/metrics  # P-API
curl http://localhost:9091/metrics  # Server A
curl http://localhost:9092/metrics  # Server B

# Ver status no Prometheus
# Acesse: http://localhost:9090/targets
```

### Serviço aparece como "DOWN" no Prometheus

1. Verifique se o serviço está rodando
2. Verifique se a porta está correta no `prometheus.yml`
3. Verifique se não há firewall bloqueando

### Instalar dependências que faltam

```bash
# Python (P-API)
cd Car_Build/P-Api
pip install prometheus-client

# Node.js (Server A e B)
cd Car_Build/Microservices
npm install prom-client express
```

---

## 📚 Queries Avançadas

### Comparar performance entre serviços

```promql
# Latência de todos os serviços
(rate(p_api_request_duration_seconds_sum[5m]) / rate(p_api_request_duration_seconds_count[5m])) or
(rate(server_a_grpc_request_duration_seconds_sum[5m]) / rate(server_a_grpc_request_duration_seconds_count[5m])) or
(rate(server_b_grpc_request_duration_seconds_sum[5m]) / rate(server_b_grpc_request_duration_seconds_count[5m]))
```

### Taxa de sucesso geral do sistema

```promql
sum(rate(p_api_requests_total{status!~"5.."}[5m])) / sum(rate(p_api_requests_total[5m])) * 100
```

### Requisições por endpoint (top 5)

```promql
topk(5, sum by (endpoint) (rate(p_api_requests_total[5m])))
```

---

## 🎓 Próximos Passos

1. **Grafana** (opcional): Interface mais bonita para visualizar métricas
   - `docker run -d -p 3001:3000 grafana/grafana`
   - Acesse http://localhost:3001
   - Configure Prometheus como datasource: http://localhost:9090

2. **Alertas**: Configure alertas para ser notificado de problemas

3. **Dashboards**: Crie dashboards personalizados no Prometheus ou Grafana

---

## 💡 Dicas

- Use intervalos `[1m]` ou `[5m]` nas queries para suavizar variações
- `rate()` é melhor que `increase()` para ver velocidade
- Percentis (P95, P99) são mais úteis que médias para latência
- Monitore sempre CPU e memória durante testes de carga

---

Configurado por: GitHub Copilot 🤖
Data: 29/11/2025
