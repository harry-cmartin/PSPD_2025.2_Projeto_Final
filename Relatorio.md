# Relatório Técnico - Projeto Final

**Curso:** Engenharia de Software  
**Disciplina:** Programação para Sistemas Paralelos e Distribuídos  
**Data:** Dezembro de 2025  
**Instituição:** Universidade de Brasília - UnB

## Equipe

| Nome Completo                     | Matrícula   |
|-----------------------------------|-------------|
| FLÁVIO GUSTAVO ARAÚJO DE MELO     | 211030602   |
| GUILHERME SILVA DUTRA             | 221021984   |
| GUSTAVO FRANCA BOA SORTE          | 211030774   |
| HARRYSON CAMPOS MARTINS           | 211039466   |

---

## 1. Introdução

### 1.1 Objetivo

Este projeto tem como objetivo principal desenvolver e analisar o desempenho de uma aplicação distribuída baseada em microserviços implantada em um cluster Kubernetes. O trabalho foca no monitoramento de aplicações containerizadas, implementando observabilidade através de ferramentas modernas como Prometheus para coleta de métricas e Locust para testes de carga.

### 1.2 Visão Geral

O projeto consiste em uma aplicação de catálogo de peças automotivas, desenvolvida com arquitetura de microserviços que se comunica via gRPC. A aplicação foi containerizada utilizando Docker e orquestrada em um cluster Kubernetes local (Kind - Kubernetes in Docker), permitindo a simulação de um ambiente distribuído realista.

A aplicação é composta por três módulos principais:
- **Módulo P (P-API)**: API Gateway desenvolvida em FastAPI que expõe endpoints REST para o frontend
- **Módulo A (Server-A)**: Microserviço de catálogo responsável por consultar peças no banco de dados
- **Módulo B (Server-B)**: Microserviço de pricing responsável por calcular orçamentos e processar compras

A infraestrutura inclui ainda um banco de dados PostgreSQL para persistência de dados, um sistema de monitoramento com Prometheus para coleta de métricas em tempo real, e Locust para simulação de carga e testes de desempenho.

### 1.3 Justificativa

Com o crescimento de aplicações distribuídas em ambientes de produção, torna-se essencial dominar ferramentas e práticas de orquestração de containers, monitoramento de sistemas e análise de desempenho. Este projeto proporciona experiência prática com tecnologias amplamente utilizadas no mercado, como Kubernetes, gRPC, Prometheus e ferramentas de containerização.

---

## 2. Metodologia de Trabalho

### 2.1 Organização da Equipe

A equipe se reuniu semanalmente durante o desenvolvimento do projeto, com encontros presenciais e remotos para planejamento, desenvolvimento colaborativo e resolução de problemas. O trabalho foi dividido em três fases principais, com responsabilidades compartilhadas entre todos os membros.

### 2.2 Cronograma de Desenvolvimento

#### Encontro 1: Montagem do Kubernetes
- **Duração**: 2 dias
- **Atividades realizadas**:
  - Estudo da arquitetura Kubernetes e conceitos de pods, deployments e services
  - Instalação e configuração do Kind (Kubernetes in Docker)
  - Criação do cluster multi-nó com 1 control-plane e 3 worker nodes
  - Desenvolvimento dos manifestos YAML para deployments e services
  - Configuração de networking entre os microserviços
  - Implementação de health checks e readiness probes
  - Setup do registry local para imagens Docker

#### Encontro 2: Configuração do Locust e Prometheus
- **Duração**: 1 dia
- **Atividades realizadas**:
  - Integração do Prometheus com os microserviços
  - Implementação de métricas customizadas (counters, histograms, gauges)
  - Exposição de endpoints `/metrics` em cada serviço
  - Configuração do arquivo `prometheus.yml` para scraping
  - Desenvolvimento do `locustfile.py` com cenários de teste
  - Criação de tarefas simulando requisições de usuários reais
  - Implementação de pesos nas tarefas para simular padrões de uso
  - Testes iniciais de conectividade e coleta de métricas

#### Encontro 3: Execução dos Testes
- **Duração**: 1 dia
- **Atividades realizadas**:
  - Definição dos cenários de teste (base, moderado, alta distribuição)
  - Execução de testes de carga com diferentes configurações
  - Coleta e análise de métricas de desempenho
  - Variação de parâmetros (réplicas, workers, carga)
  - Documentação dos resultados obtidos
  - Análise comparativa entre cenários

### 2.3 Ferramentas Utilizadas

- **Controle de versão**: Git e GitHub para versionamento de código
- **Comunicação**: Discord e WhatsApp para coordenação da equipe
- **Desenvolvimento**: VS Code como IDE principal
- **Documentação**: Markdown para documentação técnica
- **Testes**: Locust para testes de carga e Prometheus para monitoramento

---

## 3. Montagem do Kubernetes

### 3.1 Escolha da Ferramenta: Kind (Kubernetes in Docker)

Para este projeto, optamos por utilizar o **Kind (Kubernetes in Docker)** como plataforma de orquestração. Kind é uma ferramenta que permite executar clusters Kubernetes locais utilizando containers Docker como nós, sendo ideal para desenvolvimento e testes.

**Vantagens do Kind:**
- Criação rápida de clusters multi-nó
- Baixo consumo de recursos comparado a VMs
- Ambiente isolado e reproduzível
- Integração nativa com Docker
- Suporte a funcionalidades avançadas do Kubernetes

### 3.2 Arquitetura do Cluster

O cluster foi configurado com a seguinte topologia:

```yaml
# Configuração: kind-cluster-config.yaml
- 1 nó Control Plane (Master)
  - Gerencia o estado do cluster
  - Executa API Server, Scheduler, Controller Manager
  - Expõe portas 8000, 80, 443 para acesso externo

- 3 nós Workers
  - Worker 1, Worker 2, Worker 3
  - Executam os pods das aplicações
  - Labels: worker-id: "1", "2", "3"

# Redes configuradas:
- Pod Subnet: 10.244.0.0/16
- Service Subnet: 10.96.0.0/12
```

### 3.3 Processo de Instalação

O processo de instalação foi automatizado através do script `setup-kind-cluster.sh`:

```bash
# 1. Verificação de dependências
- Kind instalado
- kubectl instalado
- Docker em execução

# 2. Criação do registry local
- Registry Docker na porta 5001
- Permite push/pull de imagens localmente

# 3. Criação do cluster
kind create cluster --config=kind-cluster-config.yaml

# 4. Configuração de networking
- Conexão do registry ao cluster
- Configuração de DNS interno

# 5. Build e push das imagens
docker-compose build
docker tag car_build-server-a:latest localhost:5001/car_build-server-a:latest
docker push localhost:5001/car_build-server-a:latest
# (repetir para server-b e p-api)

# 6. Deploy dos manifestos
kubectl apply -f manifests/
```

### 3.4 Componentes Kubernetes Implementados

#### 3.4.1 Camada de Dados - PostgreSQL

**PersistentVolumeClaim (postgres-pvc.yaml)**
```yaml
kind: PersistentVolumeClaim
spec:
  resources:
    requests:
      storage: 1Gi
```
- Provisiona armazenamento persistente de 1GB
- Garante que dados sobrevivam a reinicializações

**ConfigMap (postgres-configmap.yaml)**
- Armazena script SQL de inicialização
- Cria tabelas `carros` e `pecas`
- Popula dados iniciais (Fusca, Civic, Corolla)

**Deployment (postgres-deployment.yaml)**
```yaml
image: postgres:15-alpine
ports:
  - containerPort: 5432
env:
  - POSTGRES_DB: car_build_db
  - POSTGRES_USER: car_build_user
  - POSTGRES_PASSWORD: car_build_password
```

**Service (postgres-service.yaml)**
```yaml
type: ClusterIP
```
- Cria DNS interno `postgres-service`
- Acessível apenas dentro do cluster

#### 3.4.2 Camada de Microserviços

**Server-A - Catálogo (server-a-deployment.yaml)**
```yaml
image: localhost:5001/car_build-server-a:latest
ports:
  - containerPort: 50051  # gRPC
  - containerPort: 9091   # Métricas
replicas: 1  # Configurável para testes
```
- Microserviço Node.js com gRPC
- Conecta ao PostgreSQL via DNS interno
- Expõe métricas para Prometheus

**Server-B - Pricing (server-b-deployment.yaml)**
```yaml
image: localhost:5001/car_build-server-b:latest
ports:
  - containerPort: 50052  # gRPC
  - containerPort: 9092   # Métricas
replicas: 1
```
- Calcula orçamentos e processa compras
- Implementa regras de negócio (frete, descontos)

#### 3.4.3 Camada de API Gateway

**P-API (p-api-deployment.yaml)**
```yaml
image: localhost:5001/car_build-p-api:latest
ports:
  - containerPort: 8000
env:
  - SERVER_A_HOST: server-a-service
  - SERVER_B_HOST: server-b-service
replicas: 1
```
- API Gateway FastAPI
- Converte HTTP REST para gRPC
- Configuração de CORS para frontend

**Service (p-api-service.yaml)**
```yaml
type: NodePort
ports:
  - port: 8000
    nodePort: 30080
```
- Único serviço exposto externamente
- Acessível via localhost:8000

### 3.5 Fluxo de Comunicação

```
[Cliente/Frontend]
       ↓ HTTP REST
[localhost:8000]
       ↓
[NodePort Service]
       ↓
[P-API Pod] ← Converte REST → gRPC
       ↓
[ClusterIP Services]
    ↙          ↘
[Server-A]  [Server-B]
    ↓
[PostgreSQL]
```

## 4. Monitoramento e Observabilidade

### 4.1 Prometheus: Sistema de Monitoramento

#### 4.1.1 Conceito e Arquitetura

O Prometheus é um sistema de monitoramento e alerta open-source desenvolvido pela SoundCloud e atualmente mantido pela CNCF (Cloud Native Computing Foundation). Ele coleta métricas de sistemas distribuídos através de requisições HTTP periódicas (scraping) aos endpoints `/metrics` dos serviços monitorados.

**Características principais:**
- **Modelo de Pull**: Prometheus busca ativamente as métricas (scraping)
- **Time Series Database**: Armazena dados com timestamp
- **PromQL**: Linguagem de queries poderosa para análise
- **Service Discovery**: Descobre automaticamente targets
- **Alerting**: Sistema de alertas integrado

#### 4.1.2 Configuração do Prometheus

O arquivo `prometheus.yml` define os alvos de monitoramento:

```yaml
global:
  scrape_interval: 15s      # Coleta a cada 15 segundos
  evaluation_interval: 15s   # Avalia regras a cada 15 segundos

scrape_configs:
  # P-API Gateway
  - job_name: 'p-api'
    static_configs:
      - targets: ['localhost:8000']
    metrics_path: '/metrics'

  # Microserviço Server-A
  - job_name: 'server-a'
    static_configs:
      - targets: ['localhost:9091']

  # Microserviço Server-B
  - job_name: 'server-b'
    static_configs:
      - targets: ['localhost:9092']
```

#### 4.1.4 Queries PromQL Essenciais

```promql
# Taxa de requisições por segundo
rate(p_api_requests_total[1m])

# Latência P95 (95% das requisições)
histogram_quantile(0.95, 
  rate(p_api_request_duration_seconds_bucket[5m])
) * 1000

# Taxa de erro (%)
(sum(rate(p_api_requests_total{status=~"5.."}[1m])) / 
 sum(rate(p_api_requests_total[1m]))) * 100

# Requisições ativas
p_api_active_requests

# Throughput total do sistema
sum(rate(server_a_grpc_requests_total[1m])) + 
sum(rate(server_b_grpc_requests_total[1m]))

# Latência média de queries no banco
rate(server_a_db_query_duration_seconds_sum[5m]) / 
rate(server_a_db_query_duration_seconds_count[5m])
```

### 4.2 Locust: Testes de Carga

#### 4.2.1 Conceito e Funcionalidades

Locust é uma ferramenta de teste de carga open-source escrita em Python que permite simular milhões de usuários simultâneos. Diferente de ferramentas tradicionais, Locust define o comportamento dos usuários através de código Python, oferecendo máxima flexibilidade.

**Características principais:**
- Testes definidos em código Python
- Interface web para controle e visualização
- Distribuição de carga em múltiplas máquinas
- Métricas em tempo real
- Exportação de resultados

#### 4.2.2 Implementação do Locustfile

Arquivo `locustfile.py`:

```python
from locust import HttpUser, task, between
import random

class CarBuildUser(HttpUser):
    """Simula usuários da aplicação de peças"""
    
    # Tempo de espera entre requisições (simula humanos)
    wait_time = between(1, 3)  # 1 a 3 segundos
    
    host = "http://localhost:8000"
    
    @task(1)  # Peso 1 - 7% das requisições
    def health_check(self):
        """Testa health check"""
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check falhou")
    
    @task(3)  # Peso 3 - 21% das requisições
    def get_pecas(self):
        """Busca peças de carros"""
        carros = [
            {"modelo": "Civic", "ano": 2023},
            {"modelo": "Corolla", "ano": 2020},
            {"modelo": "Fusca", "ano": 2014},
        ]
        carro = random.choice(carros)
        
        with self.client.post(
            "/get-pecas",
            json=carro,
            catch_response=True
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure("Erro ao buscar peças")
    
    @task(10)  # Peso 10 - 71% das requisições
    def calcular_preco(self):
        """Calcula preço de orçamento"""
        # Simula seleção de peças
        pecas = [
            {"id": 1, "quantidade": 1},
            {"id": 2, "quantidade": 2}
        ]
        
        with self.client.post(
            "/calcular",
            json={"itens": pecas},
            catch_response=True
        ) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure("Erro ao calcular preço")
```

#### 4.2.3 Execução de Testes

**Interface Web (Recomendado):**
```bash
./run-locust.sh
# Acesso: http://localhost:8089

# Configurar:
# - Number of users: 10, 100, 500
# - Spawn rate: 1, 10, 50
# - Host: http://localhost:8000
```

**Linha de Comando (Headless):**
```bash
# Teste leve
locust -f locustfile.py \
  --host=http://localhost:8000 \
  --users 10 --spawn-rate 2 \
  --run-time 60s --headless

# Teste médio
locust -f locustfile.py \
  --host=http://localhost:8000 \
  --users 100 --spawn-rate 10 \
  --run-time 300s --headless

# Teste intenso
locust -f locustfile.py \
  --host=http://localhost:8000 \
  --users 500 --spawn-rate 50 \
  --run-time 600s --headless
```

#### 4.2.4 Métricas Coletadas pelo Locust

- **RPS (Requests Per Second)**: Taxa de requisições
- **Response Time**: Tempo de resposta (min, max, média, P50, P95, P99)
- **Failures**: Número e percentual de falhas
- **Users**: Número de usuários simulados
- **Distribution**: Distribuição de tempos de resposta

### 4.3 Integração Prometheus + Locust

O fluxo de monitoramento funciona da seguinte forma:

```
[Locust] → Gera carga
    ↓
[P-API] → Registra métricas
    ↓
[Prometheus] → Coleta métricas a cada 15s
    ↓
[PromQL] → Analisa dados
    ↓
[Gráficos] → Visualização
```

**Monitoramento durante testes:**
```bash
# Terminal 1: Iniciar Prometheus
./start-with-prometheus.sh

# Terminal 2: Subir aplicação
kubectl apply -f manifests/

# Terminal 3: Executar Locust
locust -f locustfile.py --users 100 --spawn-rate 10

# Terminal 4: Monitorar pods
watch kubectl get pods -o wide
```

---

## 5. A Aplicação

### 5.1 Visão Geral da Arquitetura

A aplicação **Car Build** é um sistema de catálogo e orçamento de peças automotivas baseado em microserviços. A arquitetura segue o padrão API Gateway com comunicação gRPC entre serviços internos, garantindo alta performance e tipagem forte nas interfaces.

**Arquitetura de três camadas:**
1. **Frontend**: Aplicação React (não coberta neste relatório)
2. **API Gateway (P)**: FastAPI expondo REST para o frontend
3. **Microserviços (A, B)**: Serviços gRPC especializados
4. **Persistência**: PostgreSQL com dados de carros e peças

### 5.2 Tecnologias Utilizadas

| Componente | Tecnologia | Justificativa |
|------------|-----------|---------------|
| **P-API** | Python + FastAPI | Alta produtividade, async nativo, documentação automática |
| **Server-A** | Node.js + gRPC | Performance em I/O, fácil integração com gRPC |
| **Server-B** | Node.js + gRPC | Consistência tecnológica, cálculos rápidos |
| **Comunicação** | gRPC + Protocol Buffers | Performance superior a REST, tipagem forte |
| **Banco de Dados** | PostgreSQL | ACID, relacional, robusto |
| **Containerização** | Docker | Isolamento, portabilidade |
| **Orquestração** | Kubernetes (Kind) | Escalabilidade, auto-healing, load balancing |

### 5.3 Módulo P (API Gateway)

#### 5.3.1 Responsabilidades

- Expor endpoints REST para o frontend
- Converter requisições HTTP em chamadas gRPC
- Gerenciar CORS para permitir acesso do navegador
- Agregar respostas de múltiplos microserviços
- Expor métricas para Prometheus
- Implementar health checks

#### 5.3.2 Endpoints Implementados

```python
# Health Check
GET /health
Resposta: {"status": "healthy", "service": "p-api"}

# Buscar peças de um carro
POST /get-pecas
Body: {"modelo": "Fusca", "ano": 2014}
Resposta: {
  "pecas": [
    {"id": 1, "nome": "Chassi Original", "valor": 5000.0},
    {"id": 2, "nome": "Motor 1.6", "valor": 3500.0}
  ]
}

# Calcular orçamento
POST /calcular
Body: {
  "itens": [
    {"peca": {...}, "quantidade": 1},
    {"peca": {...}, "quantidade": 2}
  ]
}
Resposta: {
  "precoTotal": 12000.0,
  "frete": 45.0,
  "total": 12045.0
}

# Processar compra
POST /pagar
Body: {
  "itens": [...],
  "cliente": {...}
}
Resposta: {"success": true, "pedido_id": 123}

# Métricas Prometheus
GET /metrics
Resposta: Formato Prometheus
```


### 5.4 Módulo A (Microserviço de Catálogo)

#### 5.4.1 Responsabilidades

- Gerenciar conexão com o banco de dados PostgreSQL
- Buscar peças por modelo e ano do carro
- Buscar informações de carros disponíveis
- Expor serviço gRPC na porta 50051
- Expor métricas na porta 9091


### 5.5 Módulo B (Microserviço de Pricing)

#### 5.5.1 Responsabilidades

- Calcular preço total de orçamentos
- Aplicar regras de frete
- Validar regras de negócio (ex: apenas 1 chassi)
- Processar compras
- Expor serviço gRPC na porta 50052
- Expor métricas na porta 9092


#### 5.7.2 Fluxo de uma Requisição Completa

```
1. Cliente Frontend
   POST http://localhost:8000/get-pecas
   Body: {"modelo": "Fusca", "ano": 2014}
   
2. P-API Gateway (FastAPI)
   - Recebe HTTP POST
   - Valida entrada
   - Converte JSON → Protobuf (catalogo_pb2.Carro)
   - Incrementa métricas (REQUEST_COUNT, ACTIVE_REQUESTS)
   
3. Chamada gRPC ao Server-A
   stub_a.GetPecas(carro) via gRPC
   → Enviado para server-a-service:50051
   
4. Server-A (Node.js gRPC)
   - Recebe mensagem Protobuf
   - Extrai modelo="Fusca", ano=2014
   - Incrementa grpcRequestsTotal
   
5. Query PostgreSQL
   - Conecta via pool de conexões
   - Query: SELECT pecas WHERE modelo='Fusca' AND ano=2014
   - Registra dbQueryDuration
   
6. PostgreSQL
   - Busca dados no disco (PVC persistente)
   - Retorna: Chassi R$5000, Motor R$3500, etc.
   
7. Resposta Server-A → P-API
   - Converte rows para Protobuf (ListaPecas)
   - Envia via gRPC
   - Registra grpcRequestDuration
   
8. P-API processa resposta
   - Converte Protobuf → JSON
   - Registra REQUEST_LATENCY
   - Decrementa ACTIVE_REQUESTS
   
9. Resposta HTTP ao Cliente
   JSON: {"pecas": [{id: 1, nome: "Chassi"...}]}
   
10. Prometheus coleta métricas (15s depois)
    - Scrape /metrics de P-API, Server-A
    - Armazena time series no TSDB
```

### 5.8 Configuração Base da Aplicação

Para atender ao requisito de **configuração base** (mínima paralelização), a aplicação atual está configurada com:

```yaml
# Réplicas: 1 instância de cada serviço
p-api-deployment: replicas: 1
server-a-deployment: replicas: 1
server-b-deployment: replicas: 1
postgres-deployment: replicas: 1

# Resultado:
- Zero paralelização horizontal
- Cada requisição processada sequencialmente
- Distribuição inerente ao gRPC mantida (comunicação entre serviços)
- 1 pod por worker node (no máximo)
```

Esta configuração serve como **baseline** para comparação com cenários mais distribuídos.

---

## 6. A Aplicação (Continuação)

### 6.1 Containerização com Docker

#### 6.1.1 Dockerfile do Server-A

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copiar protos e package files
COPY protos/ /app/protos/
COPY Microservices/package*.json ./
COPY Microservices/serverA-microsservice/ ./

# Instalar dependências
RUN npm install

EXPOSE 50051 9091

CMD ["node", "index.js"]
```

#### 6.1.2 Dockerfile do Server-B

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY protos/ /app/protos/
COPY Microservices/package*.json ./
COPY Microservices/serverB-microsservice/ ./

RUN npm install

EXPOSE 50052 9092

CMD ["node", "index.js"]
```

#### 6.1.3 Dockerfile do P-API

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Instalar dependências
COPY P-Api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código
COPY P-Api/ .
COPY protos/ /app/protos/

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

#### 6.1.4 Docker Compose para Desenvolvimento Local

```yaml
version: "3.8"

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: car_build_db
      POSTGRES_USER: car_build_user
      POSTGRES_PASSWORD: car_build_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U car_build_user"]
      interval: 10s
      timeout: 5s
      retries: 5

  server-a:
    build:
      context: .
      dockerfile: ./Microservices/serverA-microsservice/Dockerfile
    ports:
      - "50051:50051"
      - "9091:9091"
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=car_build_db
      - DB_USER=car_build_user
      - DB_PASSWORD=car_build_password
    depends_on:
      postgres:
        condition: service_healthy

  server-b:
    build:
      context: .
      dockerfile: ./Microservices/serverB-microsservice/Dockerfile
    ports:
      - "50052:50052"
      - "9092:9092"

  p-api:
    build:
      context: ./P-Api
      dockerfile: ./Dockerfile
    ports:
      - "8000:8000"
    environment:
      - SERVER_A_HOST=server-a
      - SERVER_B_HOST=server-b
    depends_on:
      - server-a
      - server-b

volumes:
  postgres_data:
```

---

## 7. Cenários de Teste

### 7.1 Metodologia de Testes

### 7.2 Cenário 1: Configuração Base (Sem Paralelização)

**Objetivo:** Estabelecer baseline de desempenho

**Configuração:**
- Réplicas: 1 de cada serviço
- Workers: 3 nodes 

**Caso base - 1 usuario e 1 spawn rate**

[Teste 1 - Locust](assets/Casobase.png)

Casos de Teste:

1: 2500 Usuários - 100 Spawn Rate - 3 minutos
2: 5000 Usuários - 100 Spawn Rate - 3 minutos
3: 7500 Usuários - 100 Spawn Rate  - 3 minutos

**Resultados Obtidos: (Locust e Prometheus)**

Query utilizada para monitorar o Prometheus

![Query](assets/Query_prometheus.png)


1: 2500 Usuários - 100 Spawn Rate - 3 minutos

![Teste 1 - 2500 usuarios Locust](assets/Locust_base_2500.png)

![Teste 1 - 2500 usuarios Prometheus](assets/Prometheus_base_2500.png)

2: 5000 Usuários - 100 Spawn Rate - 3 minutos

![Teste 2 - 5000 usuarios - Locust](assets/Locust_base_5000.png)

![Teste 2 - 5000 usuarios - Prometheus](assets/Prometheus_Base_5000.png)

3: 7500 Usuários - 100 Spawn Rate  - 3 minutos

![Teste 3 - 7500 usuarios - Locust](assets/Locust_base_7500.png)

![Teste 3 - 7500 usuarios - Prometheus](assets/Prometheus_base_7500.png)



### 7.3 Cenário 2: Alteração do número de réplicas

**Objetivo:** Comparar a partir da aplicação da paralelização

**Configuração:**
- Réplicas: P-API=3, Server-A=3, Server-B=3
- Workers: 3 nodes 

Casos de Teste:

1: 2500 Usuários - 100 Spawn Rate - 3 minutos
2: 5000 Usuários - 100 Spawn Rate - 3 minutos
3: 7500 Usuários - 100 Spawn Rate  - 3 minutos

**Resultados Obtidos: (Locust e Prometheus)**

Query utilizada para monitorar o Prometheus

![Query](assets/Query_prometheus.png)

1: 2500 Usuários - 100 Spawn Rate - 3 minutos

![Teste 1 - 2500 usuarios Locust](assets/Locust_Cenario2_2500.png)

![Teste 1 - 2500 usuarios Prometheus](assets/Prometheus_Cenario2_2500.png)

2: 5000 Usuários - 100 Spawn Rate - 3 minutos

![Teste 2 - 5000 usuarios - Locust](assets/Locust_Cenario2_2500.png)

![Teste 2 - 5000 usuarios - Prometheus](assets/Prometheus_Cenario2_5000.png)

3: 7500 Usuários - 100 Spawn Rate  - 3 minutos

![Teste 3 - 7500 usuarios - Locust](assets/Locust_Cenario2_7500.png)

![Teste 3 - 7500 usuarios - Prometheus](assets/Prometheus_Cenario2_7500.png)


### 7.4 Cenário 3: Numero de Containers Por Workers

**Configuração:**
- Cluster: 3 worker nodes
- Réplicas: P-API=3, Server-A=3, Server-B=3
- Pods por workes: Worker1: 6 , Worker1: 5 , Worker1: 5 

Casos de Teste:

1: 2500 Usuários - 100 Spawn Rate - 3 minutos
2: 5000 Usuários - 100 Spawn Rate - 3 minutos
3: 7500 Usuários - 100 Spawn Rate  - 3 minutos

**Exemplo de mudança para os containers**

```yaml
# Exemplo: Car_Build/manifests/server-a-deployment.yaml
spec:
  replicas: 3
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - server-a  
              topologyKey: kubernetes.io/hostname
```


**Resultados Obtidos: (Locust e Prometheus)**


Query utilizada para monitorar o Prometheus

![Query](assets/Query_prometheus.png)

1: 2500 Usuários - 100 Spawn Rate - 3 minutos

![Teste 1 - 2500 usuarios Locust](assets/Locust_Cenario3_2500.png)

![Teste 1 - 2500 usuarios Prometheus](assets/Prometheus_Cenario3_2500.png)

2: 5000 Usuários - 100 Spawn Rate - 3 minutos

![Teste 2 - 5000 usuarios - Locust](assets/Locust_Cenario3_5000.png)

![Teste 2 - 5000 usuarios - Prometheus](assets/Prometheus_Cenario3_5000.png)

3: 7500 Usuários - 100 Spawn Rate  - 3 minutos

![Teste 3 - 7500 usuarios - Locust](assets/Locust_Cenario3_7500.png)

![Teste 3 - 7500 usuarios - Prometheus](assets/Prometheus_Cenario3_7500.png)


### 7.7 Análise Comparativa

**Conclusões Gerais:**

---

## 8. Conclusão Geral

### 8.1 Objetivos Alcançados

### 8.2 Principais Aprendizados

### 8.3 Dificuldades Encontradas

#### 8.3.1 Problemas com Kubernetes

#### 8.3.2 Desafios com gRPC

#### 8.3.3 Configuração do Prometheus

#### 8.3.4 Testes de Carga

### 8.4 Soluções Implementadas

### 8.5 Trabalhos Futuros

### 8.6 Considerações Finais

---

## 9. Conclusões Individuais

### 9.1 FLÁVIO GUSTAVO ARAÚJO DE MELO (211030602)

#### Comentários Pessoais
[ESPAÇO PARA COMENTÁRIOS]

#### Partes Trabalhadas
[ESPAÇO PARA DESCRIÇÃO]

#### Aprendizados
[ESPAÇO PARA APRENDIZADOS]

#### Nota de Autoavaliação
**Nota:** ____ / 10

**Justificativa:**

---

### 9.2 GUILHERME SILVA DUTRA (221021984)

#### Comentários Pessoais
[ESPAÇO PARA COMENTÁRIOS]

#### Partes Trabalhadas
[ESPAÇO PARA DESCRIÇÃO]

#### Aprendizados
[ESPAÇO PARA APRENDIZADOS]

#### Nota de Autoavaliação
**Nota:** ____ / 10

**Justificativa:**

---

### 9.3 GUSTAVO FRANCA BOA SORTE (211030774)

#### Comentários Pessoais
[ESPAÇO PARA COMENTÁRIOS]

#### Partes Trabalhadas
[ESPAÇO PARA DESCRIÇÃO]

#### Aprendizados
[ESPAÇO PARA APRENDIZADOS]

#### Nota de Autoavaliação
**Nota:** ____ / 10

**Justificativa:**

---

### 9.4 HARRYSON CAMPOS MARTINS (211039466)

#### Comentários Pessoais
[ESPAÇO PARA COMENTÁRIOS]

#### Partes Trabalhadas
[ESPAÇO PARA DESCRIÇÃO]

#### Aprendizados
[ESPAÇO PARA APRENDIZADOS]

#### Nota de Autoavaliação
**Nota:** ____ / 10

**Justificativa:**

---

## Referências

- [Documentação Oficial do Kubernetes](https://kubernetes.io/docs/)
- [Kind - Kubernetes in Docker](https://kind.sigs.k8s.io/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Locust Documentation](https://docs.locust.io/)
- [gRPC Documentation](https://grpc.io/docs/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Protocol Buffers](https://protobuf.dev/)

---

**Fim do Relatório**