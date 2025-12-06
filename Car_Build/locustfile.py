from locust import HttpUser, task, between
import random

class CarBuildUser(HttpUser):
    """
    Simula usuários interagindo com a API de peças de carros.
    Locust executará esses testes de carga automaticamente.
    """
    
    # Tempo de espera entre requisições (simula comportamento humano)
    wait_time = between(1, 3)  # Entre 1 e 3 segundos
    
    # Host base (pode ser sobrescrito via linha de comando)
    host = "http://localhost:8000"
    
    def on_start(self):
        """Executado uma vez quando o usuário inicia"""
        print(f"Usuário iniciado: {self.__class__.__name__}")
    
    @task(1)  
    def health_check(self):
        """Testa o endpoint de health check"""
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code == 200 and "healthy" in response.text:
                response.success()
            else:
                response.failure(f"Health check falhou: {response.status_code}")
    
    @task(3)  # Peso 3 - mais frequente
    def get_pecas(self):
        """Testa busca de peças para diferentes modelos de carro"""
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
                try:
                    data = response.json()
                    if "pecas" in data:
                        response.success()
                    else:
                        response.failure("Resposta sem campo 'pecas'")
                except Exception as e:
                    response.failure(f"Erro ao parsear JSON: {e}")
            else:
                response.failure(f"Status {response.status_code}")
    
    @task(2)
    def calcular(self):
        """Testa cálculo de orçamento com peças aleatórias"""
        
        # Primeiro busca peças
        carro = {"modelo": "Civic", "ano": 2023}
        pecas_response = self.client.post("/get-pecas", json=carro)
        
        if pecas_response.status_code == 200:
            try:
                pecas_data = pecas_response.json()
                pecas = pecas_data.get("pecas", [])
                
                if pecas:
                    
                    # Seleciona peças aleatórias para orçamento
                    num_pecas = random.randint(1, min(5, len(pecas)))
                    pecas_selecionadas = random.sample(pecas, num_pecas)
                    
                    # Adiciona quantidades
                    itens = [
                        {
                            "peca": peca,
                            "quantidade": 1
                        }
                        for peca in pecas_selecionadas
                    ]
                    
                    payload = {"itens": itens}
                    
                    with self.client.post(
                        "/calcular",
                        json=payload,
                        catch_response=True
                    ) as response:
                        if response.status_code == 200:
                            try:
                                data = response.json()
                                if "total" in data:
                                    response.success()
                                else:
                                    response.failure("Resposta sem campo 'total'")
                            except Exception as e:
                                response.failure(f"Erro ao parsear JSON: {e}")
                        else:
                            response.failure(f"Status {response.status_code}")
            except Exception as e:
                print(f"Erro no fluxo de orçamento: {e}")
    
    @task(1)
    def pagar(self):
        """Testa fluxo completo:  get pecas -> calcular -> pagar"""
        carro = {"modelo": "Corolla", "ano": 2021}
        pecas_response = self.client.post("/get-pecas", json=carro)
        
        if pecas_response.status_code == 200:
            try:
                pecas_data = pecas_response.json()
                pecas = pecas_data.get("pecas", [])
                
                if pecas:
                    # Seleciona 1-3 peças
                    num_pecas = random.randint(1, min(3, len(pecas)))
                    pecas_selecionadas = random.sample(pecas, num_pecas)
                    
                    itens = [
                        {
                            "peca": peca,
                            "quantidade": 1
                        }
                        for peca in pecas_selecionadas
                    ]
                    
                    # print(itens)
                    # Primeiro calcula
                    calc_response = self.client.post("/calcular", json={"itens": itens})
                    
                    if calc_response.status_code == 200:
                        calc_data = calc_response.json()
                        valor_total = calc_data.get("total", 0)
                        
                        # Realiza compra
                        compra_payload = {
                            "itens": itens,
                            "valor_total": valor_total
                        }
                        
                        with self.client.post(
                            "/pagar",
                            json=compra_payload,
                            catch_response=True
                        ) as response:
                            if response.status_code == 200:
                                try:
                                    data = response.json()
                                    if "pedido_id" in data or "status" in data:
                                        response.success()
                                    else:
                                        response.failure("Resposta sem pedido_id")
                                except Exception as e:
                                    response.failure(f"Erro ao parsear JSON: {e}")
                            else:
                                response.failure(f"Status {response.status_code}")
            except Exception as e:
                print(f"Erro no fluxo de compra: {e}")


class HeavyLoadUser(HttpUser):
    """
    Usuário que faz requisições mais pesadas (stress test).
    Use com menos usuários, mas mais intenso.
    """
    print("usuario pesado")
    wait_time = between(0.5, 1)  # Mais rápido
    host = "http://localhost:8000"
    
    @task
    def bombardear_get_pecas(self):
        """Faz múltiplas requisições rápidas"""
        modelos = ["Civic", "Corolla", "Fusca"]
        
        for modelo in modelos:
            self.client.post(
                "/get-pecas",
                json={"modelo": modelo, "ano": random.randint(2018, 2024)}
            )
