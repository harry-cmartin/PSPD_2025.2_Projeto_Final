# Instruções de Execução

## Pré-Requisitos
Antes de tudo, certifique-se de ter o Docker e o Docker Compose instalados na sua máquina.

Além disso, tenha o Kind instalado para criar um cluster Kubernetes local.

## Rodando o Projeto com Locust e Prometheus

- Incialmente inicie o cluster kubernetes com o comando:

```bash
cd Car_Build
./setup-kind-cluster.sh
```

- Em seguida, inicie o Prometheus com o comando:

```bash
cd Car_Build
./start-with-prometheus.sh
``` 

- Depois, inicie o locust com o comando:

```bash
cd Car_Build/
./run-locust.sh
``` 

- Por fim, acesse o locust no navegador através do link: **http://localhost:8089**

- E acesse o Prometheus no navegador através do link: **http://localhost:9090**

- Para rodar os testes de carga, basta definir o número de usuários e a taxa de spawn na interface web do locust.