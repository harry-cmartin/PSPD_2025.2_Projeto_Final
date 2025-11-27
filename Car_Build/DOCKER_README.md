# Car Build - Microservices com Docker

## Arquitetura

Este projeto usa uma arquitetura de microserviços com:

- **P-Api**: API Gateway FastAPI (porta 8000) - recebe requisições HTTP e faz chamadas gRPC
- **Server A**: Microserviço de Catálogo gRPC (porta 50051) - gerencia carros e peças  
- **Server B**: Microserviço de Pricing gRPC (porta 50052) - calcula preços e orçamentos

## Como rodar com Docker

### 1. Construir e iniciar todos os serviços

```bash
cd Car_Build
docker-compose up --build
```

### 2. Rodar em background (detached)

```bash
docker-compose up -d --build
```

### 3. Ver logs dos serviços

```bash
# Todos os logs
docker-compose logs -f

# Logs de um serviço específico
docker-compose logs -f p-api
docker-compose logs -f server-a  
docker-compose logs -f server-b
```

### 4. Parar os serviços

```bash
docker-compose down
```

## URLs dos Serviços

- **P-Api (FastAPI)**: http://localhost:8000
- **Documentação da API**: http://localhost:8000/docs  
- **Server A (gRPC)**: localhost:50051
- **Server B (gRPC)**: localhost:50052

## Testando a API

Você pode testar os endpoints usando a documentação automática do FastAPI em:
http://localhost:8000/docs

### Endpoints disponíveis:

#### POST /get-pecas
Busca peças disponíveis para um modelo de carro:
```json
{
  "modelo": "fusca", 
  "ano": 2014
}
```

#### POST /calcular  
Calcula o preço total de um orçamento:
```json
{
  "itens": [
    {
      "peca": {
        "id": "1",
        "nome": "Chassi", 
        "valor": 5000.00
      },
      "quantidade": 1
    }
  ]
}
```

## Desenvolvimento

Para desenvolvimento local sem Docker, você ainda pode rodar cada serviço separadamente:

### P-Api (FastAPI)
```bash
cd P-Api
pip install -r requirements.txt
uvicorn app:app --reload --port 8000
```

### Server A (Catálogo)
```bash
cd Microservices/serverA-microsservice  
npm install
node index.js
```

### Server B (Pricing)
```bash
cd Microservices/serverB-microsservice
npm install  
node index.js
```

## Estrutura dos Containers

- **car-build-p-api**: Container do FastAPI Gateway
- **car-build-server-a**: Container do microserviço de Catálogo
- **car-build-server-b**: Container do microserviço de Pricing
- **car-build-network**: Rede Docker para comunicação entre containers