# Arquitetura Kubernetes

Nesta aplicação, utilizamos o Minikube, uma ferramenta que cria e gerencia um cluster Kubernetes completo, porém simplificado, que roda localmente na máquina.

O diferencial do Minikube, é que ele é um cluster que o Minikube cria é um cluster de nó único (host unico), enquanto um cluster de produção geralmente é composto por múltiplos nós (computadores)

## Componentes e Manifestos

### **1. Camada de Dados (PostgreSQL)**

#### `postgres-pvc.yaml` - Armazenamento Persistente

```yaml
kind: PersistentVolumeClaim
```

**Função**: Reserva 1GB de disco persistente no cluster

- **Por que?**: Dados do PostgreSQL precisam sobreviver a reinicializações
- **Comportamento**: Mesmo se o pod morrer, os dados permanecem salvos

#### `postgres-configmap.yaml` - Script de Inicialização

```yaml
kind: ConfigMap
data:
  init.sql: |
    CREATE TABLE carros...
    CREATE TABLE pecas...
```

**Função**: Armazena o script SQL que cria tabelas e popula dados

- **Execução**: Roda automaticamente na primeira inicialização do PostgreSQL
- **Conteúdo**: Tabelas `carros` e `pecas` + dados iniciais (Fusca, Civic, Corolla)

#### `postgres-deployment.yaml` - Container do Banco

```yaml
kind: Deployment
image: postgres:15-alpine
```

**Função**: Executa o PostgreSQL no cluster

- **Volumes**: Conecta PVC criado (dados) + ConfigMap (script SQL)
- **Ambiente**: Define as variáveis de ambiente do banco. Essas credenciais são utilizadas tanto pelo contêiner do banco quanto pelos serviços que irão se conectar a ele.
- **Porta**: 5432 (exposta internamente no cluster para acesso pelas aplicações).

#### `postgres-service.yaml` - Rede Interna do Banco

```yaml
kind: Service
type: ClusterIP
```

**Função**: Cria um serviço interno para expor o PostgreSQL dentro do cluster.

- **DNS interno**: Gera automaticamente o nome `postgres-service`, que pode ser usado por outros Pods para se conectar ao banco sem precisar do IP direto.
- **Acesso**: Direciona o tráfego recebido na porta 5432 para os Pods do Deployment do PostgreSQL.
- **Isolamento**: Por ser do tipo ClusterIP, o serviço só é acessível de dentro do cluster, garantindo que o banco não fique exposto externamente.

---

### **2. Camada de Microserviços (Containers A & B)**

#### `server-a-deployment.yaml` - Microserviço de Catálogo

```yaml
kind: Deployment
image: car_build-server-a:latest
env:
  - name: DB_HOST
    value: "postgres-service"
```

**Função**: Container A - Microserviço gRPC de catálogo

- **Responsabilidade**: Buscar peças por modelo de carro
- **Tecnologia**: Node.js + gRPC
- **Banco**: Conecta no PostgreSQL via DNS interno
- **Porta**: 50051 (gRPC)

#### `server-a-service.yaml` - DNS do Catálogo

```yaml
kind: Service
type: ClusterIP
```

**Função**: Cria DNS `server-a-service` para acesso interno

#### `server-b-deployment.yaml` - Microserviço de Pricing

```yaml
kind: Deployment
image: car_build-server-b:latest
```

**Função**: Container B - Microserviço gRPC de cálculo de preços

- **Responsabilidade**: Calcular preços totais dos orçamentos
- **Tecnologia**: Node.js + gRPC
- **Porta**: 50052 (gRPC)

#### `server-b-service.yaml` - DNS do Pricing

```yaml
kind: Service
type: ClusterIP
```

**Função**: Cria DNS `server-b-service` para acesso interno

---

### **3. Camada de API Gateway (Container P)**

#### `p-api-deployment.yaml` - API Gateway

```yaml
kind: Deployment
image: car_build-p-api:latest
env:
  - name: SERVER_A_HOST
    value: "server-a-service"
  - name: SERVER_B_HOST
    value: "server-b-service"
```

**Função**: Executa o API Gateway (Container P), que serve como ponte entre o frontend e os serviços internos.

- **Rede Externa**: Recebe requisições HTTP do frontend
- **Rede Interna**: Converte para gRPC e chama Server A/B
- **Ambiente**: Define variáveis (`SERVER_A_HOST` e `SERVER_B_HOST`) que apontam para os serviços internos no cluster, garantindo que o Gateway saiba como se comunicar com eles via DNS do Kubernetes.
- **Tecnologia**: Construído em FastAPI com clientes gRPC para orquestrar as chamadas.
- **CORS**: Configurado para permitir que o frontend (mesmo rodando em localhost) consiga acessar a API sem bloqueios de navegador.

#### `p-api-service.yaml` - Exposição Externa

```yaml
kind: Service
type: LoadBalancer
```

**Função**: **ÚNICA** Torna o API Gateway acessível de fora do cluster.

- **Tipo**: LoadBalancer funciona com `minikube tunnel` para expor o serviço externamente em porta fixa
- **Comando**: `minikube tunnel` cria túnel persistente em `localhost:8000`
- **Resultado**: O frontend pode se conectar ao cluster em URL fixa, sem precisar conhecer os serviços internos.

---

## **Fluxo Completo de uma Requisição**

### **1. Buscar Peças de um Carro:**

```
1. [Frontend React] 
   POST http://localhost:8000/get-pecas
   Body: {"modelo": "fusca", "ano": 2014}
   ↓
   
2. [minikube tunnel] 
   Encaminha para cluster Kubernetes
   ↓
   
3. [p-api-service LoadBalancer] 
   DNS resolve para pod p-api-deployment
   ↓4. [Container P - FastAPI]
   - Recebe HTTP POST
   - Converte para gRPC
   - Chama server-a-service via DNS interno
   ↓

5. [Container A - Server gRPC]
   - Recebe gRPC GetPecas()
   - Conecta postgres-service via DNS
   - Query SQL: SELECT * FROM pecas WHERE modelo_fk = 'fusca'
   ↓

6. [PostgreSQL]
   - Busca dados no PVC persistente
   - Retorna: Chassi R$5000, Motor 1.6 R$3500, etc.
   ↓

7. [Resposta volta pelo caminho inverso]
   PostgreSQL → Server A → P-API → Tunnel → Frontend
```

### **2. Calcular Preço Total:**

```
1. [Frontend] Envia peças selecionadas para /calcular
2. [Container P] Converte HTTP → gRPC
3. [Container B] Recebe lista de peças e quantidades
4. [Container B] Calcula: (quantidade × valor) para cada peça
5. [Resposta] Preço total retorna para frontend
```

---

## **Tipos de Services e Redes**

| Service | Tipo | Acesso | Função |
|---------|------|--------|---------|
| `postgres-service` | ClusterIP | Apenas interno | DNS do banco |
| `server-a-service` | ClusterIP | Apenas interno | DNS do catálogo |  
| `server-b-service` | ClusterIP | Apenas interno | DNS do pricing |
| `p-api-service` | **LoadBalancer** | **Externo** | **Gateway público** |

### **Redes Configuradas:**

- **Rede Externa**: Frontend ↔ P-API (HTTP tradicional)
- **Rede Interna**: P-API ↔ Server A/B (HTTP/2 gRPC)

---

### **Comandos:**

```bash
# 1. Subir minikube
minikube start

# 2. Carregar imagens
minikube image load car_build-p-api:latest
minikube image load car_build-server-a:latest
minikube image load car_build-server-b:latest

# 3. Deploy todos os manifests
kubectl apply -f .

# 4. Aguardar pods iniciarem
kubectl get pods -w

# 5. Expor P-API externalmente
minikube service p-api-service

# 6. Executar frontend
npm start
```

---

## **Verificação e Monitoramento**

### **Comandos Úteis:**

```bash
# Ver status dos pods
kubectl get pods

# Ver logs de um serviço
kubectl logs -f deployment/p-api-deployment
kubectl logs -f deployment/server-a-deployment

# Testar conectividade interna
kubectl exec -it deployment/postgres-deployment -- psql -U car_build_user -d car_build_db

# Dashboard visual
minikube dashboard
```

## **Conformidade com Especificação**

Esta implementação atende perfeitamente aos requisitos:

- **HServ**: Kubernetes cluster (minikube)
- **HClient**: Browser com frontend React
- **Container P**: API Gateway (HTTP ↔ gRPC)
- **Container A**: Microserviço catálogo gRPC
- **Container B**: Microserviço pricing gRPC
- **Rede Externa**: HTTP tradicional via LoadBalancer + minikube tunnel
- **Rede Interna**: HTTP/2 gRPC entre containers
- **Persistência**: PostgreSQL com PVC 

---

## **Seção Completa sobre Kubernetes - Arquitetura e Funcionalidades**

### **1. Processo de Desenvolvimento e Migração para Kubernetes**

#### **1.1 Etapa Inicial - Containerização com Docker**

O desenvolvimento iniciou com a criação de **Dockerfiles individuais** para cada microserviço:

- **Microserviço A (Catálogo)**: `./Microservices/serverA-microsservice/Dockerfile`
- **Microserviço B (Pricing)**: `./Microservices/serverB-microsservice/Dockerfile`
- **API Gateway (P-API)**: `./P-Api/Dockerfile`

Após a containerização individual, foi criado um **docker-compose.yml** para:

- **Orquestrar todos os serviços** em uma única rede (`car-build-network`)
- **Definir dependências** entre serviços (healthchecks)
- **Gerenciar volumes** para persistência do PostgreSQL
- **Testar a comunicação** entre containers antes da migração

---

### **2. Arquitetura Kubernetes Implementada**

#### **2.1 Minikube**

**Escolha Tecnológica**: Minikube foi selecionado por ser:

- **Ambiente Local**: Ideal para desenvolvimento e testes
- **Cluster Completo**: Simula um cluster Kubernetes real em nó único
- **Facilidade de Uso**: Setup rápido sem configurações complexas

#### **2.2 Componentes de Infraestrutura**

##### **A) Persistent Volume Claims (PVC)**

```yaml
# postgres-pvc.yaml
kind: PersistentVolumeClaim
spec:
  resources:
    requests:
      storage: 1Gi
```

**Justificativa de Uso**:

- **Persistência de Dados**: Garante que dados PostgreSQL sobrevivam a reinicializações de pods
- **Desacoplamento**: Separa o lifecycle do storage do lifecycle do container
- **Portabilidade**: Permite migração entre nodes sem perda de dados

##### **B) ConfigMaps**

```yaml
# postgres-configmap.yaml
kind: ConfigMap
data:
  init.sql: |
    CREATE TABLE carros...
    CREATE TABLE pecas...
```

**Justificativa de Uso**:

- **Separação de Configuração**: Remove scripts SQL do código da aplicação
- **Versionamento**: Permite controle de versão das configurações
- **Reutilização**: Configurações podem ser compartilhadas entre ambientes

#### **2.3 Camada de Deployments**

##### **A) PostgreSQL Deployment**

```yaml
# postgres-deployment.yaml
kind: Deployment
spec:
  replicas: 1
  template:
    spec:
      containers:
        - image: postgres:15-alpine
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql/data
            - name: init-script
              mountPath: /docker-entrypoint-initdb.d
```

**Estratégia Adotada**:

- **Volume Mounting**: PVC para dados + ConfigMap para inicialização
- **Single Replica**: Para bancos estateful, uma réplica evita problemas de sincronização

##### **B) Microserviços Deployments**

```yaml
# server-a-deployment.yaml / server-b-deployment.yaml
kind: Deployment
spec:
  replicas: 1
  template:
    spec:
      containers:
        - image: car_build-server-a:latest
          imagePullPolicy: IfNotPresent
          env:
            - name: DB_HOST
              value: "postgres-service"
```

**Decisões de Design**:

- **ImagePullPolicy: IfNotPresent**: Otimiza build local com minikube
- **Variáveis de Ambiente**: Injeção de configuração via Kubernetes
- **Service Discovery**: Uso de DNS interno (`postgres-service`)

##### **C) API Gateway Deployment**

```yaml
# p-api-deployment.yaml
kind: Deployment
spec:
  template:
    spec:
      containers:
        - image: car_build-p-api:latest
          env:
            - name: SERVER_A_HOST
              value: "server-a-service"
            - name: SERVER_B_HOST
              value: "server-b-service"
```

**Arquitetura Gateway Pattern**:

- **Centralização**: Único ponto de entrada para requisições externas
- **Conversão de Protocolo**: HTTP REST para gRPC internamente
- **Service Mesh**: Comunicação com microserviços via DNS interno

---

### **3. Configuração de Rede e Services**

#### **3.1 Services Internos (ClusterIP)**

**Postgres Service**:

```yaml
# postgres-service.yaml
kind: Service
spec:
  type: ClusterIP
  ports:
    - port: 5432
      targetPort: 5432
```

**Microserviços Services**:

```yaml
# server-a-service.yaml / server-b-service.yaml
kind: Service
spec:
  type: ClusterIP
  ports:
    - port: 50051/50052
      targetPort: 50051/50052
```

**Justificativa ClusterIP**:

- **Segurança**: Serviços não expostos externamente
- **Performance**: Comunicação direta entre pods
- **Service Discovery**: DNS automático (`service-name.namespace.svc.cluster.local`)

#### **3.2 Service Externo (LoadBalancer)**

```yaml
# p-api-service.yaml
kind: Service
spec:
  type: LoadBalancer
  ports:
    - port: 8000
      targetPort: 8000
```

**Justificativa LoadBalancer**:

- **Acesso Externo**: Permite conexão do frontend React em porta fixa
- **Desenvolvimento**: Ideal para ambiente local com minikube tunnel
- **URL Fixa**: Sempre disponível em `localhost:8000` com `minikube tunnel`

---

### **4. Comandos de Implementação e Dificuldades**

#### **4.1 Sequência de Comandos Utilizados**

```bash
# 1. Preparação do Ambiente
minikube start
minikube dashboard  # Opcional - monitoramento visual

# 2. Build e Load das Imagens Docker
docker-compose up --build  # Gera imagens locais
minikube image load car_build-p-api:latest
minikube image load car_build-server-a:latest
minikube image load car_build-server-b:latest

# 3. Deploy da Infraestrutura (ordem importante)
cd manifests
kubectl apply -f postgres-pvc.yaml          # Storage primeiro
kubectl apply -f postgres-configmap.yaml    # Configurações
kubectl apply -f postgres-deployment.yaml   # Database
kubectl apply -f postgres-service.yaml      # DNS interno

# 4. Deploy dos Microserviços
kubectl apply -f server-a-deployment.yaml
kubectl apply -f server-a-service.yaml
kubectl apply -f server-b-deployment.yaml
kubectl apply -f server-b-service.yaml

# 5. Deploy do API Gateway
kubectl apply -f p-api-deployment.yaml
kubectl apply -f p-api-service.yaml

# 6. Verificação e Exposição
kubectl get deployments
kubectl get pods -w  # Aguardar todos ficarem Running
minikube service p-api-service  # Criar túnel externo

# 7. Frontend
cd ../WebClient
npm start
```

#### **4.2 Dificuldades Encontradas**

##### **A) Gerenciamento de Imagens**

**Problema**: Kubernetes não encontrava imagens Docker locais
**Solução**: Uso do `minikube image load` para transferir imagens para o cluster interno
**Lição**: Minikube possui registry interno separado do Docker local

##### **B) Service Discovery e DNS**

**Problema**: Microserviços não conseguiam se conectar usando hostnames do docker-compose
**Solução**: Migração para DNS interno do Kubernetes (`service-name`)
**Configuração**: Variáveis de ambiente apontando para services (`postgres-service`, `server-a-service`)

##### **C) Dependências de Inicialização**

**Problema**: Pods tentavam conectar no PostgreSQL antes dele estar pronto
**Solução**: Uso de `kubectl get pods -w` para aguardar status `Running`
**Melhoria**: Implementação de health checks nos Deployments

##### **D) Persistência de Dados**

**Problema**: Dados PostgreSQL eram perdidos a cada restart do pod
**Solução**: Implementação de PersistentVolumeClaim
**Configuração**: Volume mounting correto nos Deployments

##### **E) Exposição Externa**

**Problema**: Frontend não conseguia acessar API Gateway
**Solução**: Service tipo LoadBalancer + comando `minikube tunnel`
**Resultado**: Túnel automático em porta fixa (localhost:8000)

---

### **5. Resultados Alcançados**

#### **5.1 Arquitetura Final Funcional**

**Infraestrutura Obtida**:

- **Cluster Kubernetes** funcional com minikube
- **4 Deployments** independentes e escaláveis
- **5 Services** com DNS interno funcional
- **Persistent Volume** para dados PostgreSQL
- **ConfigMap** para scripts de inicialização
- **Rede Externa** via LoadBalancer + minikube tunnel funcional
- **Comunicação gRPC** interna entre microserviços

#### **5.2 Benefícios Obtidos vs Docker Compose**

| Aspecto                  | Docker Compose    | Kubernetes                |
| ------------------------ | ----------------- | ------------------------- |
| **Escalabilidade**       | Manual, limitada  | Automática por deployment |
| **Alta Disponibilidade** | Restart simples   | Redistribuição automática |
| **Service Discovery**    | Hostnames fixos   | DNS dinâmico              |
| **Monitoramento**        | Logs básicos      | Dashboard + métricas      |
| **Configuração**         | Environment files | ConfigMaps + Secrets      |
| **Networking**           | Bridge network    | Service mesh              |

#### **5.3 Funcionalidades Implementadas**

**Orquestração Completa**:

- **Auto-restart** de containers com falhas
- **Load balancing** interno entre réplicas
- **Service discovery** automático via DNS
- **Volume management** para persistência
- **Configuration management** via ConfigMaps

**Monitoramento e Observabilidade**:

- Dashboard visual via `minikube dashboard`
- Logs centralizados via `kubectl logs`
- Status de health via `kubectl get pods`
- Métricas de recursos via Kubernetes API

#### **5.4 Validação da Arquitetura**

**Testes de Integração Realizados**:

```bash
# 1. Conectividade Database
kubectl exec -it deployment/postgres-deployment -- psql -U car_build_user -d car_build_db

# 2. Comunicação gRPC Interna
kubectl logs -f deployment/p-api-deployment  # Verificar calls para server-a/b

# 3. Acesso Externo
curl http://$(minikube service p-api-service --url)/get-pecas
```

**Resultados dos Testes**:

- PostgreSQL inicializado com dados
- Server-A respondendo queries gRPC de catálogo
- Server-B calculando preços via gRPC
- P-API convertendo HTTP→gRPC corretamente
- Frontend React consumindo APIs

---

### **6. Conclusões e Lições Aprendidas**

#### **6.1 Vantagens da Migração**

**Técnicas**:

- **Isolamento**: Cada serviço em namespace próprio
- **Escalabilidade**: Réplicas independentes por deployment
- **Resiliência**: Auto-recovery e redistribuição
- **Flexibilidade**: Configuração declarativa via YAML

**Operacionais**:

- **Padronização**: Mesma interface para todos os ambientes
- **Versionamento**: Controle de versão de toda infraestrutura
- **Debugging**: Ferramentas avançadas de troubleshooting

