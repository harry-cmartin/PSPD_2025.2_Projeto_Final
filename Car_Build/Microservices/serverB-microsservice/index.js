const grpc = require("@grpc/grpc-js");
const protoLoader = require("@grpc/proto-loader");

const packageDef = protoLoader.loadSync("protos/pricing.proto", {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
  includeDirs: ["protos"],
});
const proto = grpc.loadPackageDefinition(packageDef).pricing;

const calcularPrecoTotal = (itens) => {
  let precoTotal = 0;

  const chassiCount = itens
    .filter((item) => item.peca.nome.toLowerCase().includes("chassi"))
    .reduce((total, item) => total + item.quantidade, 0);

  if (chassiCount > 1) {
    throw new Error("Somente um chassi é permitido por pedido");
  }

  itens.forEach((item) => {
    const valorItem = item.peca.valor * item.quantidade;
    precoTotal += valorItem;
  });

  // Calcular frete
  const frete = calcularFrete(precoTotal, itens);
  const total = precoTotal + frete;

  return { precoTotal, frete, total };
};

const calcularFrete = (subtotal, itens) => {
  const totalItens = itens.reduce((sum, item) => sum + item.quantidade, 0);
  const fretePorItem = 15.00; // R$ 15 por item
  let freteCalculado = totalItens * fretePorItem;
  
  // Frete grátis acima de R$ 10.000
  if (subtotal > 10000) {
    freteCalculado = 0;
  }
  
  // Frete mínimo de R$ 20
  if (freteCalculado > 0 && freteCalculado < 20) {
    freteCalculado = 20;
  }
  
  return freteCalculado;
};

const pricingService = {
  Calcular: (call, callback) => {
    try {
      const { itens } = call.request;

      console.log(
        `[SERVER B] Calculando preço para ${itens.length} tipos de itens`
      );

      itens.forEach((item, index) => {
        console.log(
          `[SERVER B] Item ${index + 1}: ${item.peca.nome} (ID: ${
            item.peca.id
          }) - Qtd: ${item.quantidade} - Valor unitário: R$ ${item.peca.valor}`
        );
      });

      const { precoTotal, frete, total } = calcularPrecoTotal(itens);

      const response = {
        preco: precoTotal,
        frete: frete,
        total: total,
      };

      console.log(
        `[SERVER B] Preço calculado - Subtotal: R$ ${precoTotal.toFixed(2)}, Frete: R$ ${frete.toFixed(2)}, Total: R$ ${total.toFixed(2)}`
      );

      callback(null, response);
    } catch (error) {
      console.error(`[SERVER B] Erro ao calcular preço: ${error.message}`);

      callback({
        code: grpc.status.INVALID_ARGUMENT,
        message: error.message,
      });
    }
  },

  RealizarCompra: (call, callback) => {
    try {
      const { itens, valor_total } = call.request;

      console.log(
        `[SERVER B] Processando compra para ${itens.length} tipos de itens`
      );

      // Validar novamente o preço
      const { precoTotal, frete, total } = calcularPrecoTotal(itens);

      // Verificar se o valor total confere (tolerância de 1 centavo)
      if (Math.abs(total - valor_total) > 0.01) {
        throw new Error(
          `Valor total não confere. Calculado: R$ ${total.toFixed(2)}, Enviado: R$ ${valor_total.toFixed(2)}`
        );
      }

      // Gerar ID único do pedido
      const pedidoId = `PED-${Date.now()}-${Math.random().toString(36).substr(2, 9).toUpperCase()}`;

      // Simular salvamento no banco (futuramente pode ser implementado)
      const pedido = {
        id: pedidoId,
        itens: itens,
        subtotal: precoTotal,
        frete: frete,
        total: total,
        data: new Date().toISOString(),
        status: "CONFIRMADO",
      };

      console.log(`[SERVER B] Pedido criado:`, {
        id: pedido.id,
        total: `R$ ${pedido.total.toFixed(2)}`,
        itens: pedido.itens.length,
      });

      const response = {
        pedido_id: pedidoId,
        status: "CONFIRMADO",
        valor_total: total,
        data_pedido: pedido.data,
        itens_comprados: itens,
        subtotal: precoTotal,
        frete: frete,
      };

      callback(null, response);
    } catch (error) {
      console.error(`[SERVER B] Erro ao processar compra: ${error.message}`);

      callback({
        code: grpc.status.INVALID_ARGUMENT,
        message: error.message,
      });
    }
  },
};

const server = new grpc.Server();
server.addService(proto.OrcamentoService.service, pricingService);

const serverAddress = "0.0.0.0:50052";
server.bindAsync(
  serverAddress,
  grpc.ServerCredentials.createInsecure(),
  (err, port) => {
    if (err) {
      console.error("Erro ao iniciar servidor B:", err);
      return;
    }

    console.log(
      `[SERVER B] Microserviço B (Pricing) rodando em ${serverAddress}`
    );
    server.start();
  }
);
