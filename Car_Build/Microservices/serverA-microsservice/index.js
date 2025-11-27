const grpc = require("@grpc/grpc-js");
const protoLoader = require("@grpc/proto-loader");
const { Pool } = require("pg");

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
  const client = await pool.connect();
  try {
    const query = `
      SELECT id, nome, valor 
      FROM pecas 
      WHERE LOWER(modelo_fk) = LOWER($1)
      ORDER BY nome
    `;
    const result = await client.query(query, [modelo]);
    return result.rows;
  } finally {
    client.release();
  }
}

const catalogoService = {
  GetPecas: async (call, callback) => {
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
      callback(null, response);
    } catch (error) {
      console.error(`[SERVER A] Erro ao buscar peças para ${modelo}:`, error);
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
