const grpc = require("@grpc/grpc-js");
const protoLoader = require("@grpc/proto-loader");
const { Pool } = require("pg");
const express = require("express");
const promClient = require("prom-client");

const register = new promClient.Registry();

// Métricas padrão do sistema (CPU, memória, etc.)
promClient.collectDefaultMetrics({ register });

// Métricas customizadas para Server A
const grpcRequestsTotal = new promClient.Counter({
  name: 'server_a_grpc_requests_total',
  help: 'Total de requisições gRPC recebidas',
  labelNames: ['method', 'status'],
  registers: [register]
});

const grpcRequestDuration = new promClient.Histogram({
  name: 'server_a_grpc_request_duration_seconds',
  help: 'Duração das requisições gRPC em segundos',
  labelNames: ['method'],
  registers: [register]
});

const dbQueriesTotal = new promClient.Counter({
  name: 'server_a_db_queries_total',
  help: 'Total de queries executadas no banco de dados',
  labelNames: ['status'],
  registers: [register]
});

const dbQueryDuration = new promClient.Histogram({
  name: 'server_a_db_query_duration_seconds',
  help: 'Duração das queries de banco em segundos',
  registers: [register]
});

const dbConnectionsActive = new promClient.Gauge({
  name: 'server_a_db_connections_active',
  help: 'Número de conexões ativas com o banco de dados',
  registers: [register]
});

// Servidor HTTP Express para expor métricas
const metricsApp = express();
metricsApp.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

const METRICS_PORT = process.env.METRICS_PORT || 9091;
metricsApp.listen(METRICS_PORT, () => {
  console.log(`[SERVER A] Métricas Prometheus disponíveis em http://localhost:${METRICS_PORT}/metrics`);
});

const packageDef = protoLoader.loadSync("protos/catalogo.proto", {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
  includeDirs: ["protos"],
});
const proto = grpc.loadPackageDefinition(packageDef).catalogo;

// Configuração do PostgreSQL
const pool = new Pool({
  host: process.env.DB_HOST || "localhost",
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || "car_build_db",
  user: process.env.DB_USER || "car_build_user",
  password: process.env.DB_PASSWORD || "car_build_password",
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Monitorar conexões do pool
pool.on('connect', () => {
  dbConnectionsActive.inc();
});

pool.on('remove', () => {
  dbConnectionsActive.dec();
});

// Conexão do banco com retry
async function connectToDatabase() {
  const maxRetries = 10;
  let retries = 0;

  while (retries < maxRetries) {
    try {
      const client = await pool.connect();
      console.log("[SERVER A] Conectado ao PostgreSQL com sucesso!");
      client.release();
      return;
    } catch (error) {
      retries++;
      console.log(
        `[SERVER A] Tentativa ${retries}/${maxRetries} de conexão com PostgreSQL...`
      );
      console.log(`[SERVER A] Erro: ${error.message}`);

      if (retries === maxRetries) {
        console.error(
          "[SERVER A] Falha ao conectar ao PostgreSQL após múltiplas tentativas"
        );
        throw error;
      }
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }
  }
}

// Função para buscar peças do banco de dados
async function getPecasFromDatabase(modelo) {
  const startTime = Date.now();
  const client = await pool.connect();
  
  try {
    const query = `
      SELECT id, nome, valor 
      FROM pecas 
      WHERE LOWER(modelo_fk) = LOWER($1)
      ORDER BY nome
    `;
    const result = await client.query(query, [modelo]);
    
    // Registra sucesso da query
    dbQueriesTotal.labels('success').inc();
    dbQueryDuration.observe((Date.now() - startTime) / 1000);
    
    return result.rows;
  } catch (error) {
    // Registra erro da query
    dbQueriesTotal.labels('error').inc();
    throw error;
  } finally {
    client.release();
  }
}

const catalogoService = {
  GetPecas: async (call, callback) => {
    const startTime = Date.now();
    const { modelo, ano } = call.request;

    console.log(
      `[SERVER A] Recebida requisição para modelo: ${modelo}, ano: ${ano}`
    );

    try {
      // Busca peças no banco de dados
      const pecasDoModelo = await getPecasFromDatabase(modelo);

      // Converte os dados para o formato esperado pelo gRPC
      const pecasFormatadas = pecasDoModelo.map((peca) => ({
        id: peca.id.toString(),
        nome: peca.nome,
        valor: parseFloat(peca.valor),
      }));

      const response = {
        pecas: pecasFormatadas,
      };

      console.log(
        `[SERVER A] Retornando ${pecasFormatadas.length} peças para ${modelo}`
      );
      
      // Registra sucesso da requisição gRPC
      grpcRequestsTotal.labels('GetPecas', 'success').inc();
      grpcRequestDuration.labels('GetPecas').observe((Date.now() - startTime) / 1000);
      
      callback(null, response);
    } catch (error) {
      console.error(`[SERVER A] Erro ao buscar peças para ${modelo}:`, error);
      
      // Registra erro da requisição gRPC
      grpcRequestsTotal.labels('GetPecas', 'error').inc();
      grpcRequestDuration.labels('GetPecas').observe((Date.now() - startTime) / 1000);
      
      callback({
        code: grpc.status.INTERNAL,
        message: `Erro interno ao buscar peças: ${error.message}`,
      });
    }
  },
};

// Inicializar servidor
async function startServer() {
  try {
    await connectToDatabase();

    const server = new grpc.Server();
    server.addService(proto.CatalogoService.service, catalogoService);

    const serverAddress = "0.0.0.0:50051";
    server.bindAsync(
      serverAddress,
      grpc.ServerCredentials.createInsecure(),
      (err, port) => {
        if (err) {
          console.error("[SERVER A] Erro ao iniciar servidor:", err);
          return;
        }

        console.log(
          `[SERVER A] Microserviço A (Catálogo) rodando em ${serverAddress}`
        );
        server.start();
      }
    );
  } catch (error) {
    console.error("[SERVER A] Falha ao inicializar servidor:", error);
    process.exit(1);
  }
}

startServer();
