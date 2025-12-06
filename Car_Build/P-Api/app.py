
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from google.protobuf import json_format
import grpc
import os
import time
import generated.catalogo_pb2 as catalogo_pb2
import generated.catalogo_pb2_grpc as catalogo_pb2_grpc
import generated.pricing_pb2 as pricing_pb2
import generated.pricing_pb2_grpc as pricing_pb2_grpc
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST


# Métricas customizadas para monitoramento
REQUEST_COUNT = Counter(
    'p_api_requests_total', 
    'Total de requisições recebidas pela P-API',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'p_api_request_duration_seconds',
    'Latência das requisições em segundos',
    ['method', 'endpoint']
)

GRPC_CALLS = Counter(
    'p_api_grpc_calls_total',
    'Total de chamadas gRPC para microserviços',
    ['service', 'status']
)

ACTIVE_REQUESTS = Gauge(
    'p_api_active_requests',
    'Número de requisições ativas no momento'
)

app = FastAPI()

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",     
        "http://127.0.0.1:3000",  
        "http://localhost:30080",  
        "http://127.0.0.1:52261",  
        "*"                       
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Usar variáveis de ambiente para hostnames dos containers
SERVER_A_HOST = os.getenv("SERVER_A_HOST", "localhost")
SERVER_B_HOST = os.getenv("SERVER_B_HOST", "localhost")

stub_a = catalogo_pb2_grpc.CatalogoServiceStub(grpc.insecure_channel(f"{SERVER_A_HOST}:50051"))
stub_b = pricing_pb2_grpc.OrcamentoServiceStub(grpc.insecure_channel(f"{SERVER_B_HOST}:50052"))

@app.get("/metrics", response_class=PlainTextResponse)
def metrics():
    """Endpoint que expõe as métricas para o Prometheus coletar"""
    return generate_latest()

@app.get("/health")
def health_check():
    """Endpoint de health check para Kubernetes liveness/readiness probes"""
    REQUEST_COUNT.labels(method='GET', endpoint='/health', status='200').inc()
    return {"status": "healthy", "service": "p-api"}

@app.post("/get-pecas")
def get_pecas(body: dict):
    ACTIVE_REQUESTS.inc()  # Incrementa requisições ativas
    start_time = time.time()
    
    try:
        carro = catalogo_pb2.Carro()
        json_format.ParseDict(body, carro)
        resp = stub_a.GetPecas(carro)
        
        # Registra sucesso
        REQUEST_COUNT.labels(method='POST', endpoint='/get-pecas', status='200').inc()
        GRPC_CALLS.labels(service='server-a', status='success').inc()
        
        return json_format.MessageToDict(resp)
    
    except Exception as e:
        REQUEST_COUNT.labels(method='POST', endpoint='/get-pecas', status='500').inc()
        GRPC_CALLS.labels(service='server-a', status='error').inc()
        raise
    
    finally:
        # Registra latência e decrementa requisições ativas
        REQUEST_LATENCY.labels(method='POST', endpoint='/get-pecas').observe(time.time() - start_time)
        ACTIVE_REQUESTS.dec()


@app.post("/calcular")
def calcular(body: dict):
    ACTIVE_REQUESTS.inc()
    start_time = time.time()
    
    try:
        req = pricing_pb2.OrcamentoRequest()
        json_format.ParseDict(body, req)
        resp = stub_b.Calcular(req)
        
        REQUEST_COUNT.labels(method='POST', endpoint='/calcular', status='200').inc()
        GRPC_CALLS.labels(service='server-b', status='success').inc()
        
        return json_format.MessageToDict(resp)
    
    except Exception as e:
        REQUEST_COUNT.labels(method='POST', endpoint='/calcular', status='500').inc()
        GRPC_CALLS.labels(service='server-b', status='error').inc()
        raise
    
    finally:
        REQUEST_LATENCY.labels(method='POST', endpoint='/calcular').observe(time.time() - start_time)
        ACTIVE_REQUESTS.dec()


@app.post("/pagar")
def pagar(body: dict):
    ACTIVE_REQUESTS.inc()
    start_time = time.time()
    
    try:
        print(f"[P-API] Recebida requisição de compra: {body}")
        
        # Criar request de compra
        req = pricing_pb2.CompraRequest()
        json_format.ParseDict(body, req)
        
        # Chamar Server B para processar compra
        resp = stub_b.RealizarCompra(req)
        
        # Converter resposta para dict
        result = json_format.MessageToDict(resp)
        
        print(f"[P-API] Compra processada com sucesso. Pedido ID: {result.get('pedidoId', 'N/A')}")
        
        REQUEST_COUNT.labels(method='POST', endpoint='/pagar', status='200').inc()
        GRPC_CALLS.labels(service='server-b', status='success').inc()
        
        return result
        
    except grpc.RpcError as e:
        print(f"[P-API] Erro gRPC ao processar compra: {e.details()}")
        REQUEST_COUNT.labels(method='POST', endpoint='/pagar', status='400').inc()
        GRPC_CALLS.labels(service='server-b', status='error').inc()
        raise HTTPException(status_code=400, detail=f"Erro ao processar compra: {e.details()}")
    except Exception as e:
        print(f"[P-API] Erro interno ao processar compra: {str(e)}")
        REQUEST_COUNT.labels(method='POST', endpoint='/pagar', status='500').inc()
        GRPC_CALLS.labels(service='server-b', status='error').inc()
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")
    
    finally:
        REQUEST_LATENCY.labels(method='POST', endpoint='/pagar').observe(time.time() - start_time)
        ACTIVE_REQUESTS.dec()
