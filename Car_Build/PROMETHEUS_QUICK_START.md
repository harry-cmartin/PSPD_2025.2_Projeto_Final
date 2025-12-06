# 🎯 Resumo Rápido - Prometheus Configurado!

## ✅ O que foi feito?

### 1. Configuração do Prometheus
- ✅ `prometheus.yml` configurado para monitorar 4 serviços
- ✅ Coleta de métricas a cada 10 segundos
- ✅ Retenção de dados por 15 dias

### 2. Métricas Adicionadas nos Serviços

#### P-API (FastAPI - porta 8000)
- ✅ Contador de requisições HTTP
- ✅ Histograma de latência
- ✅ Gauge de requisições ativas
- ✅ Contador de chamadas gRPC
- ✅ Endpoint `/metrics` exposto

#### Server A (Node.js - porta 9091)
- ✅ Contador de requisições gRPC
- ✅ Histograma de latência gRPC
- ✅ Contador de queries SQL
- ✅ Histograma de latência SQL
- ✅ Gauge de conexões ativas no DB
- ✅ Servidor HTTP Express para métricas

#### Server B (Node.js - porta 9092)
- ✅ Contador de requisições gRPC
- ✅ Histograma de latência
- ✅ Contador de cálculos realizados
- ✅ Contador de compras processadas
- ✅ Contador de valor total em vendas
- ✅ Servidor HTTP Express para métricas

### 3. Scripts Criados
- ✅ `start-with-prometheus.sh` - Inicia o Prometheus
- ✅ `test-prometheus.sh` - Testa a configuração
- ✅ `PROMETHEUS_GUIDE.md` - Guia completo de uso

---

## 🚀 Como Usar (Passo a Passo)

### Passo 1: Instalar Dependências

```bash
cd Car_Build/Microservices
npm install

cd ../P-Api
pip install -r requirements.txt
```

### Passo 2: Iniciar Prometheus

```bash
cd Car_Build
./start-with-prometheus.sh
```

Deixe este terminal aberto! O Prometheus estará rodando.

### Passo 3: Iniciar Seus Serviços

Em **outro terminal**:

```bash
# Opção A: Docker Compose
cd Car_Build
docker-compose up

# Opção B: Kubernetes com Kind
./setup-kind-cluster.sh

# Opção C: Manualmente
# (consulte o PROMETHEUS_GUIDE.md)
```

### Passo 4: Acessar o Prometheus

Abra no navegador: **http://localhost:9090**

### Passo 5: Testar

```bash
cd Car_Build
./test-prometheus.sh
```

---

## 📊 Métricas Principais

### Para Monitorar Performance

```promql
# Requisições por segundo
rate(p_api_requests_total[1m])

# Latência P95 (95% das requisições)
histogram_quantile(0.95, rate(p_api_request_duration_seconds_bucket[5m]))

# Taxa de erro
sum(rate(p_api_requests_total{status="500"}[1m]))
```

### Para Testes de Carga

```promql
# Throughput total
sum(rate(p_api_requests_total[1m]))

# Requisições ativas (concorrência)
p_api_active_requests

# Queries no banco por segundo
rate(server_a_db_queries_total[1m])

# Compras processadas
rate(server_b_compras_processadas_total[1m])
```

---

## 🧪 Fazer Teste de Carga

### Teste Simples com curl

```bash
# Loop de 100 requisições
for i in {1..100}; do
  curl http://localhost:8000/health &
done

# Acompanhe no Prometheus:
rate(p_api_requests_total{endpoint="/health"}[30s])
```

### Teste com Apache Bench

```bash
# Instalar
sudo apt install apache2-utils

# Executar teste
ab -n 1000 -c 50 http://localhost:8000/health

# Monitorar no Prometheus durante o teste
```

---

## 🎯 URLs Importantes

| Serviço | URL |
|---------|-----|
| **Prometheus Web UI** | http://localhost:9090 |
| **P-API** | http://localhost:8000 |
| **P-API Metrics** | http://localhost:8000/metrics |
| **Server A Metrics** | http://localhost:9091/metrics |
| **Server B Metrics** | http://localhost:9092/metrics |
| **Frontend** | http://localhost:3000 |

---

## 📖 Documentação Completa

Leia o guia detalhado: **`PROMETHEUS_GUIDE.md`**

Contém:
- ✅ Todas as queries úteis
- ✅ Como fazer testes de carga completos
- ✅ Troubleshooting
- ✅ Queries avançadas
- ✅ Métricas de negócio

---

## 🎓 Entendendo o Prometheus

### O que ele faz?

1. **Coleta métricas** dos seus serviços a cada 10 segundos
2. **Armazena** essas métricas em um banco de dados de séries temporais
3. **Permite consultar** com PromQL (linguagem de queries)
4. **Visualiza** em gráficos

### Por que é útil para testes?

- 📊 Ver quantas requisições por segundo seu sistema aguenta
- ⏱️ Medir latência (tempo de resposta)
- 🐛 Detectar erros em tempo real
- 💾 Monitorar uso de banco de dados
- 📈 Comparar performance antes/depois de mudanças

### Exemplo prático:

**Antes do teste:**
```promql
rate(p_api_requests_total[1m])
# Resultado: 0 req/s
```

**Durante o teste de carga:**
```promql
rate(p_api_requests_total[1m])
# Resultado: 150 req/s
```

**Latência aumentou?**
```promql
histogram_quantile(0.95, rate(p_api_request_duration_seconds_bucket[5m]))
# Resultado: 0.08s (80ms) - Bom! ✅
```

---

## 🎨 Arquitetura

```
┌─────────────┐
│  Frontend   │ (localhost:3000)
│   React     │
└──────┬──────┘
       │ HTTP
       ▼
┌─────────────┐     ┌──────────────┐
│   P-API     │────▶│ Prometheus   │
│  (port 8000)│     │  (port 9090) │
└──────┬──────┘     └──────────────┘
       │ gRPC              ▲
       ├────────┐          │
       ▼        ▼          │
┌──────────┐ ┌──────────┐ │
│ Server A │ │ Server B │ │
│(gRPC:9091│ │(gRPC:9092│─┘
│Metrics)  │ │Metrics)  │
└────┬─────┘ └──────────┘
     │
     ▼
┌──────────┐
│PostgreSQL│
└──────────┘
```

Cada serviço expõe `/metrics` que o Prometheus coleta automaticamente!

---

## 💡 Dicas Finais

1. **Mantenha o Prometheus rodando** enquanto faz testes
2. **Use intervalos de 1m ou 5m** nas queries para ver tendências
3. **Preste atenção no P95 e P99** (percentis), não na média
4. **Monitore CPU e memória** durante testes pesados
5. **Faça testes graduais**: 10 req/s → 50 req/s → 100 req/s

---

## 🆘 Problemas Comuns

### "Nenhum serviço aparece no Prometheus"
- ✅ Certifique-se que os serviços estão rodando
- ✅ Aguarde ~30 segundos para primeira coleta
- ✅ Verifique em Status > Targets

### "Métricas não estão sendo coletadas"
```bash
# Testar endpoints manualmente
curl http://localhost:8000/metrics
curl http://localhost:9091/metrics
curl http://localhost:9092/metrics
```

### "Dependências faltando"
```bash
# Python
pip install prometheus-client

# Node.js
npm install prom-client express
```

---

**Está tudo pronto! 🎉**

Comece executando:
```bash
./start-with-prometheus.sh
```

E depois acesse: http://localhost:9090

Boa sorte com seus testes! 🚀
