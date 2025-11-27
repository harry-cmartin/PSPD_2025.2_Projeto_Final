
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from google.protobuf import json_format
import grpc
import os
import generated.catalogo_pb2 as catalogo_pb2
import generated.catalogo_pb2_grpc as catalogo_pb2_grpc
import generated.pricing_pb2 as pricing_pb2
import generated.pricing_pb2_grpc as pricing_pb2_grpc

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

@app.get("/health")
def health_check():
    """Endpoint de health check para Kubernetes liveness/readiness probes"""
    return {"status": "healthy", "service": "p-api"}

@app.post("/get-pecas")
def get_pecas(body: dict):
    carro = catalogo_pb2.Carro()
    json_format.ParseDict(body, carro)
    resp = stub_a.GetPecas(carro)
    return json_format.MessageToDict(resp)


@app.post("/calcular")
def calcular(body: dict):
   req = pricing_pb2.OrcamentoRequest()
   json_format.ParseDict(body, req)
   resp = stub_b.Calcular(req)
   return json_format.MessageToDict(resp)


@app.post("/pagar")
def pagar(body: dict):
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
        
        return result
        
    except grpc.RpcError as e:
        print(f"[P-API] Erro gRPC ao processar compra: {e.details()}")
        raise HTTPException(status_code=400, detail=f"Erro ao processar compra: {e.details()}")
    except Exception as e:
        print(f"[P-API] Erro interno ao processar compra: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")
