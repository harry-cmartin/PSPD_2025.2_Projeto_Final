# 📊 Cheat Sheet - Queries Prometheus para Testes de Carga

## 🎯 Copy & Paste - Queries Essenciais

### 📈 PERFORMANCE GERAL

```promql
# Taxa de requisições por segundo (throughput)
rate(p_api_requests_total[1m])

# Requisições por segundo por endpoint
sum by (endpoint) (rate(p_api_requests_total[1m]))

# Total acumulado de requisições
sum(p_api_requests_total)

# Requisições ativas neste momento
p_api_active_requests
```

### ⚡ LATÊNCIA (TEMPO DE RESPOSTA)

```promql
# Latência média em milissegundos
rate(p_api_request_duration_seconds_sum[1m]) / rate(p_api_request_duration_seconds_count[1m]) * 1000

# Latência P50 (mediana) - 50% das requisições são mais rápidas
histogram_quantile(0.50, rate(p_api_request_duration_seconds_bucket[5m])) * 1000

# Latência P95 - 95% das requisições são mais rápidas
histogram_quantile(0.95, rate(p_api_request_duration_seconds_bucket[5m])) * 1000

# Latência P99 - 99% das requisições são mais rápidas
histogram_quantile(0.99, rate(p_api_request_duration_seconds_bucket[5m])) * 1000

# Latência máxima observada
max_over_time(p_api_request_duration_seconds_sum[5m])
```

### 🚨 ERROS E TAXA DE SUCESSO

```promql
# Taxa de erro (requisições 5xx por segundo)
sum(rate(p_api_requests_total{status=~"5.."}[1m]))

# Taxa de erro em porcentagem
(sum(rate(p_api_requests_total{status=~"5.."}[1m])) / sum(rate(p_api_requests_total[1m]))) * 100

# Taxa de sucesso (%)
(sum(rate(p_api_requests_total{status=~"2.."}[1m])) / sum(rate(p_api_requests_total[1m]))) * 100

# Requisições por status code
sum by (status) (rate(p_api_requests_total[1m]))
```

### 💾 BANCO DE DADOS (Server A)

```promql
# Queries por segundo
rate(server_a_db_queries_total[1m])

# Taxa de erro em queries
sum(rate(server_a_db_queries_total{status="error"}[1m]))

# Conexões ativas com PostgreSQL
server_a_db_connections_active

# Tempo médio de query em milissegundos
(rate(server_a_db_query_duration_seconds_sum[1m]) / rate(server_a_db_query_duration_seconds_count[1m])) * 1000

# Queries mais lentas (P99)
histogram_quantile(0.99, rate(server_a_db_query_duration_seconds_bucket[5m])) * 1000
```

### 🔌 gRPC (Server A e B)

```promql
# Requisições gRPC Server A por segundo
rate(server_a_grpc_requests_total[1m])

# Requisições gRPC Server B por segundo
rate(server_b_grpc_requests_total[1m])

# Taxa de sucesso gRPC Server A (%)
(sum(rate(server_a_grpc_requests_total{status="success"}[1m])) / sum(rate(server_a_grpc_requests_total[1m]))) * 100

# Latência média gRPC Server A (ms)
(rate(server_a_grpc_request_duration_seconds_sum[1m]) / rate(server_a_grpc_request_duration_seconds_count[1m])) * 1000

# Latência média gRPC Server B (ms)
(rate(server_b_grpc_request_duration_seconds_sum[1m]) / rate(server_b_grpc_request_duration_seconds_count[1m])) * 1000
```

### 💰 MÉTRICAS DE NEGÓCIO (Server B)

```promql
# Cálculos de orçamento por minuto
rate(server_b_calculos_realizados_total[1m]) * 60

# Compras processadas por minuto
rate(server_b_compras_processadas_total{status="CONFIRMADO"}[1m]) * 60

# Valor total vendido (R$)
server_b_valor_total_compras_reais

# Taxa de conversão (compras / cálculos) em %
(server_b_compras_processadas_total / server_b_calculos_realizados_total) * 100

# Ticket médio (valor médio por compra)
server_b_valor_total_compras_reais / server_b_compras_processadas_total{status="CONFIRMADO"}
```

### 💻 RECURSOS DO SISTEMA

```promql
# Uso de CPU por serviço (%)
rate(process_cpu_seconds_total[1m]) * 100

# Uso de memória em MB
process_resident_memory_bytes / 1024 / 1024

# Uso de memória do P-API
process_resident_memory_bytes{job="p-api"} / 1024 / 1024

# Uso de memória do Server A
process_resident_memory_bytes{job="server-a"} / 1024 / 1024

# Uso de memória do Server B
process_resident_memory_bytes{job="server-b"} / 1024 / 1024
```

---

## 🧪 QUERIES PARA DURANTE TESTES DE CARGA

### Dashboard de Teste em Tempo Real

Cole estas queries em abas separadas do Prometheus durante o teste:

**Aba 1 - Throughput:**
```promql
sum(rate(p_api_requests_total[10s]))
```

**Aba 2 - Latência P95:**
```promql
histogram_quantile(0.95, rate(p_api_request_duration_seconds_bucket[1m])) * 1000
```

**Aba 3 - Erros:**
```promql
sum(rate(p_api_requests_total{status=~"5.."}[10s]))
```

**Aba 4 - Requisições Ativas:**
```promql
p_api_active_requests
```

**Aba 5 - Load no Banco:**
```promql
server_a_db_connections_active
```

---

## 📊 QUERIES DE ANÁLISE PÓS-TESTE

### Estatísticas Gerais

```promql
# Total de requisições durante o teste
sum(increase(p_api_requests_total[5m]))

# Requisições por endpoint
sum by (endpoint) (increase(p_api_requests_total[5m]))

# Pico de throughput (req/s)
max_over_time(rate(p_api_requests_total[30s])[5m:30s])

# Latência média durante o teste
avg_over_time((rate(p_api_request_duration_seconds_sum[1m]) / rate(p_api_request_duration_seconds_count[1m]))[5m:])
```

### Identificar Gargalos

```promql
# Endpoint mais lento (latência P99)
topk(1, histogram_quantile(0.99, sum by (endpoint) (rate(p_api_request_duration_seconds_bucket[5m]))))

# Endpoint com mais erros
topk(1, sum by (endpoint) (rate(p_api_requests_total{status=~"5.."}[5m])))

# Serviço com maior latência
max(
  rate(p_api_request_duration_seconds_sum[1m]) / rate(p_api_request_duration_seconds_count[1m]),
  rate(server_a_grpc_request_duration_seconds_sum[1m]) / rate(server_a_grpc_request_duration_seconds_count[1m]),
  rate(server_b_grpc_request_duration_seconds_sum[1m]) / rate(server_b_grpc_request_duration_seconds_count[1m])
)
```

---

## 🎯 QUERIES POR CENÁRIO DE TESTE

### Cenário 1: Teste de Stress (Alta Carga)

**Monitorar:**
```promql
# 1. Sistema está aguentando?
rate(p_api_requests_total[10s]) > 0

# 2. Latência está aumentando?
histogram_quantile(0.95, rate(p_api_request_duration_seconds_bucket[30s])) * 1000

# 3. Conexões no banco estão saturando?
server_a_db_connections_active

# 4. Taxa de erro está crescendo?
(sum(rate(p_api_requests_total{status=~"5.."}[30s])) / sum(rate(p_api_requests_total[30s]))) * 100
```

### Cenário 2: Teste de Pico (Burst)

**Monitorar:**
```promql
# 1. Requisições ativas (deve voltar a 0 após o pico)
p_api_active_requests

# 2. Pico de throughput atingido
max_over_time(rate(p_api_requests_total[10s])[2m:10s])

# 3. Recuperação após pico (deve estabilizar)
rate(p_api_request_duration_seconds_sum[30s]) / rate(p_api_request_duration_seconds_count[30s])
```

### Cenário 3: Teste de Resistência (Soak Test)

**Monitorar ao longo do tempo:**
```promql
# 1. Vazamento de memória? (deve ser constante)
process_resident_memory_bytes{job="p-api"} / 1024 / 1024

# 2. Conexões não liberadas? (deve ser estável)
server_a_db_connections_active

# 3. Performance degrada com tempo?
histogram_quantile(0.95, rate(p_api_request_duration_seconds_bucket[5m])) * 1000
```

---

## 🔍 QUERIES AVANÇADAS

### Comparação de Múltiplos Serviços

```promql
# Latência de todos os serviços lado a lado
(rate(p_api_request_duration_seconds_sum[1m]) / rate(p_api_request_duration_seconds_count[1m])) * 1000 or
(rate(server_a_grpc_request_duration_seconds_sum[1m]) / rate(server_a_grpc_request_duration_seconds_count[1m])) * 1000 or
(rate(server_b_grpc_request_duration_seconds_sum[1m]) / rate(server_b_grpc_request_duration_seconds_count[1m])) * 1000
```

### Top 5 Endpoints Mais Lentos

```promql
topk(5, 
  histogram_quantile(0.95, 
    sum by (endpoint) (rate(p_api_request_duration_seconds_bucket[5m]))
  )
) * 1000
```

### Taxa de Erro Agregada do Sistema

```promql
(
  sum(rate(p_api_requests_total{status=~"5.."}[1m])) +
  sum(rate(server_a_grpc_requests_total{status="error"}[1m])) +
  sum(rate(server_b_grpc_requests_total{status="error"}[1m]))
) / (
  sum(rate(p_api_requests_total[1m])) +
  sum(rate(server_a_grpc_requests_total[1m])) +
  sum(rate(server_b_grpc_requests_total[1m]))
) * 100
```

---

## 📋 TEMPLATE PARA RELATÓRIO DE TESTE

Após fazer o teste de carga, documente com estas queries:

```markdown
## Relatório de Teste de Carga

**Data:** [data]
**Duração:** [tempo]
**Carga aplicada:** [req/s]

### Métricas Gerais
- Total de requisições: `sum(increase(p_api_requests_total[5m]))`
- Throughput médio: `avg_over_time(rate(p_api_requests_total[1m])[5m:])`
- Throughput máximo: `max_over_time(rate(p_api_requests_total[30s])[5m:30s])`

### Latência
- P50: `histogram_quantile(0.50, rate(p_api_request_duration_seconds_bucket[5m])) * 1000` ms
- P95: `histogram_quantile(0.95, rate(p_api_request_duration_seconds_bucket[5m])) * 1000` ms
- P99: `histogram_quantile(0.99, rate(p_api_request_duration_seconds_bucket[5m])) * 1000` ms

### Erros
- Taxa de erro: `(sum(rate(p_api_requests_total{status=~"5.."}[5m])) / sum(rate(p_api_requests_total[5m]))) * 100` %

### Recursos
- CPU máxima: `max_over_time(rate(process_cpu_seconds_total[1m])[5m:]) * 100` %
- Memória máxima: `max_over_time(process_resident_memory_bytes[5m:]) / 1024 / 1024` MB
- Conexões DB máximas: `max_over_time(server_a_db_connections_active[5m:])`

### Conclusão
[Análise dos resultados]
```

---

## 💡 DICAS DE USO

1. **Use `[1m]` para dados em tempo real** durante o teste
2. **Use `[5m]` para análise pós-teste** (mais suave)
3. **Sempre multiplique por 1000** para converter segundos em milissegundos
4. **Use `increase()` para contar eventos** num período
5. **Use `rate()` para ver velocidade** (eventos por segundo)
6. **Percentis > Média** - P95 e P99 são mais importantes que avg

---

## 🎓 ENTENDENDO OS RESULTADOS

### Throughput (Requisições/segundo)
- **< 10 req/s**: Baixo, teste local
- **10-100 req/s**: Médio, aplicação pequena
- **100-1000 req/s**: Alto, aplicação de produção
- **> 1000 req/s**: Muito alto, sistema enterprise

### Latência
- **< 100ms**: Excelente ⭐⭐⭐
- **100-300ms**: Bom ⭐⭐
- **300-500ms**: Aceitável ⭐
- **> 500ms**: Precisa otimizar ⚠️

### Taxa de Erro
- **< 0.1%**: Excelente
- **0.1-1%**: Aceitável
- **1-5%**: Atenção necessária
- **> 5%**: Problema crítico

---

**Pronto para testar! 🚀**

Copie as queries acima diretamente no Prometheus (http://localhost:9090) e analise seus resultados!
