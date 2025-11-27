import React, { useState } from "react";
import "./CartPage.css";
import "./App.js";
import axios from "axios";
import { getApiUrl } from "./useApiUrl";

function CartPage({
  pricing,
  selectedParts,
  parts,
  onBack,
  purchaseResult,
  setPurchaseResult,
  getTotalItems,
  setPurchaseLoading,
  returnHome,
}) {
  const API_URL = getApiUrl();
  const [showConfirmation, setShowConfirmation] = useState(false);
  //   const [purchaseResult, setPurchaseResult] = useState(initialPurchaseResult || null);

  // Itens selecionados
  const itensSelecionados = Object.entries(selectedParts).map(([id, qtd]) => {
    const peca = parts.find((p) => p.id === id);
    return { ...peca, quantidade: qtd };
  });

  const total = (pricing?.preco || 0) + (pricing?.frete || 0);

  const Return = () => {
    returnHome();
    onBack();
  };

  // Componente de confirmação de compra
  const PurchaseConfirmation = ({ purchaseResult }) => {
    if (!purchaseResult) return null;

    return (
      <div className="purchase-confirmation">
        <header className="header">
          <h1>✅ Compra Realizada com Sucesso!</h1>
        </header>

        <div className="main-content">
          <div className="purchase-details">
            <div className="order-summary">
              <h2>
                Pedido: {purchaseResult.pedidoId || purchaseResult.pedido_id}
              </h2>
              <div className="order-info">
                <p>
                  <strong>Status:</strong> {purchaseResult.status}
                </p>
                <p>
                  <strong>Data:</strong>{" "}
                  {new Date(
                    purchaseResult.dataPedido || purchaseResult.data_pedido
                  ).toLocaleString("pt-BR")}
                </p>
              </div>

              <div className="pricing-breakdown">
                <h3>💰 Resumo Financeiro</h3>
                <div className="pricing-line">
                  <span>Subtotal:</span>
                  <span>
                    R${" "}
                    {(purchaseResult.subtotal || 0).toLocaleString("pt-BR", {
                      minimumFractionDigits: 2,
                    })}
                  </span>
                </div>
                <div className="pricing-line">
                  <span>Frete:</span>
                  <span>
                    R${" "}
                    {(purchaseResult.frete || 0).toLocaleString("pt-BR", {
                      minimumFractionDigits: 2,
                    })}
                  </span>
                </div>
                <div className="pricing-total">
                  <span>Total Pago:</span>
                  <span>
                    R${" "}
                    {(
                      purchaseResult.valorTotal ||
                      purchaseResult.valor_total ||
                      0
                    ).toLocaleString("pt-BR", { minimumFractionDigits: 2 })}
                  </span>
                </div>
              </div>

              <div className="items-purchased">
                <h3>📦 Itens Comprados</h3>
                {(
                  purchaseResult.itensComprados ||
                  purchaseResult.itens_comprados ||
                  []
                ).map((item, index) => (
                  <div key={index} className="purchased-item">
                    <span className="item-qty">{item.quantidade}x</span>
                    <span className="item-name">{item.peca.nome}</span>
                    <span className="item-price">
                      R${" "}
                      {(
                        Number(item.peca.valor) * Number(item.quantidade)
                      ).toLocaleString("pt-BR", { minimumFractionDigits: 2 })}
                    </span>
                  </div>
                ))}
              </div>

              <div className="button-wrapper">
                <button className="return-home" onClick={Return}>
                  🏠 Página inicial
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  };

  const handleConfirmPurchase = async () => {
    if (!pricing || getTotalItems() === 0) return;

    setPurchaseLoading(true);

    try {
      // Monta os itens do pedido
      const itens = Object.entries(selectedParts).map(
        ([partId, quantidade]) => {
          const part = parts.find((p) => p.id === partId);
          return {
            peca: {
              id: part.id,
              nome: part.nome,
              valor: part.valor,
            },
            quantidade: quantidade,
          };
        }
      );

      const valorTotal = (pricing.preco || 0) + (pricing.frete || 0);

      // Chamada para o back-end
      const response = await axios.post(`${API_URL}/pagar`, {
        itens: itens,
        valor_total: valorTotal,
      });

      // Salva o resultado da compra
      setPurchaseResult(response.data);

      // Mostra a tela de confirmação
      setShowConfirmation(true);
    } catch (error) {
      console.error("Erro ao finalizar compra:", error);
      alert(
        `Erro ao finalizar compra: ${
          error.response?.data?.detail || error.message
        }`
      );
    } finally {
      setPurchaseLoading(false);
    }
  };

  // Renderiza carrinho ou confirmação
  if (showConfirmation && purchaseResult) {
    return <PurchaseConfirmation purchaseResult={purchaseResult} />;
  }

  return (
    <div className="cart-page">
      <header className="cart-header">
        <button onClick={onBack} className="back-button">
          ⬅️
        </button>
        <h1>🛒 Meu Carrinho</h1>
      </header>

      <main className="cart-content">
        {itensSelecionados.length === 0 ? (
          <p className="empty-cart">Seu carrinho está vazio.</p>
        ) : (
          <div className="cart-details">
            <h2>Itens Selecionados</h2>
            <ul className="cart-items-list">
              {itensSelecionados.map((item) => (
                <li key={item.id} className="cart-item">
                  <span>
                    {item.quantidade}x {item.nome}
                  </span>
                  <strong>
                    R${" "}
                    {(item.valor * item.quantidade).toLocaleString("pt-BR", {
                      minimumFractionDigits: 2,
                    })}
                  </strong>
                </li>
              ))}
            </ul>

            <div className="cart-summary">
              <p>
                Subtotal:{" "}
                <strong>
                  R${" "}
                  {pricing?.preco?.toLocaleString("pt-BR", {
                    minimumFractionDigits: 2,
                  })}
                </strong>
              </p>
              <p>
                Frete:{" "}
                <strong>
                  R${" "}
                  {pricing?.frete?.toLocaleString("pt-BR", {
                    minimumFractionDigits: 2,
                  })}
                </strong>
              </p>
              <p className="cart-total">
                💰 Total:{" "}
                <strong>
                  R${" "}
                  {total.toLocaleString("pt-BR", { minimumFractionDigits: 2 })}
                </strong>
              </p>
            </div>

            <button className="finalize-button" onClick={handleConfirmPurchase}>
              Confirmar Compra
            </button>
          </div>
        )}
      </main>
    </div>
  );
}

export default CartPage;
