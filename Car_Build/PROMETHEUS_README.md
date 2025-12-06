# 🚀 Start Here - Prometheus

## Passo a Passo Simples

### 1. Instalar dependências (primeira vez)
```bash
cd Car_Build/Microservices
npm install

cd ../P-Api
pip install -r requirements.txt
```

### 2. Iniciar Prometheus
```bash
cd Car_Build
./start-with-prometheus.sh
```
> Deixe este terminal aberto!

### 3. Iniciar seus serviços (em outro terminal)
```bash
# Seu método normal: docker-compose, kind, ou manual
```

### 4. Acessar Prometheus
Abra no navegador: **http://localhost:9090**

### 5. Testar
```bash
./test-prometheus.sh
```

---

## 📚 Documentação

- **Inicio Rápido**: `PROMETHEUS_QUICK_START.md` - Comece aqui!
- **Guia Completo**: `PROMETHEUS_GUIDE.md` - Tudo sobre Prometheus
- **Queries Prontas**: `PROMETHEUS_QUERIES.md` - Copy & paste queries

---

## 🎯 Queries Essenciais

Cole no Prometheus (Graph):

```promql
# Requisições por segundo
rate(p_api_requests_total[1m])

# Latência P95
histogram_quantile(0.95, rate(p_api_request_duration_seconds_bucket[5m])) * 1000

# Taxa de erro (%)
(sum(rate(p_api_requests_total{status=~"5.."}[1m])) / sum(rate(p_api_requests_total[1m]))) * 100
```

---

## 🧪 Fazer Teste de Carga Simples

```bash
# Teste com 100 requisições
for i in {1..100}; do curl http://localhost:8000/health & done

# Ou com Apache Bench
ab -n 1000 -c 50 http://localhost:8000/health
```

Depois veja as métricas no Prometheus!

---

## 📊 URLs

| Serviço | URL |
|---------|-----|
| Prometheus | http://localhost:9090 |
| P-API | http://localhost:8000 |
| P-API Metrics | http://localhost:8000/metrics |
| Server A Metrics | http://localhost:9091/metrics |
| Server B Metrics | http://localhost:9092/metrics |

---

## ❓ Problemas?

```bash
# Verificar se Prometheus está rodando
curl http://localhost:9090/-/healthy

# Verificar métricas dos serviços
curl http://localhost:8000/metrics
curl http://localhost:9091/metrics
curl http://localhost:9092/metrics
```

---

**Pronto! É só isso.** 🎉

Para mais detalhes, leia `PROMETHEUS_QUICK_START.md`
