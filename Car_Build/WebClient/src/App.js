import React, { useState, useEffect } from "react";
import axios from "axios";
import CartPage from "./CartPage";
import { getApiUrl } from "./useApiUrl";

function App() {
  const [selectedCar, setSelectedCar] = useState(null);
  const [parts, setParts] = useState([]);
  const [selectedParts, setSelectedParts] = useState({});
  const [pricing, setPricing] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [purchaseResult, setPurchaseResult] = useState(null);
  const [showCartPage, setShowCartPage] = useState(false);

  // URL fixa da API
  const API_URL = getApiUrl();

  const mockCarros = [
    { modelo: "fusca", ano: 2014 },
    { modelo: "civic", ano: 2023 },
    { modelo: "corolla", ano: 2020 },
  ];

  // Abrir carrinho
  const onOpenCart = () => {
    if (getTotalItems() > 0) {
      setShowCartPage(true);
    } else {
      alert("Seu carrinho está vazio! Adicione alguns itens primeiro.");
    }
  };

  const onBackFromCart = () => {
    setShowCartPage(false);
  };

  // Resetar app para nova compra
  const restartApp = () => {
    setSelectedCar(null);
    setSelectedParts({});
    setPricing(null);
    setPurchaseResult(null);
    setShowCartPage(false);
  };

  // Selecionar carro e buscar peças
  const handleCarSelect = async (car) => {
    setSelectedCar(car);
    setSelectedParts({});
    setPricing(null);
    setLoading(true);
    setError(null);

    try {
      const response = await axios.post(`${API_URL}/get-pecas`, {
        modelo: car.modelo,
        ano: car.ano,
      });

      setParts(response.data.pecas || []);
    } catch (err) {
      setError(
        `Erro ao buscar peças: ${err.response?.data?.detail || err.message}`
      );
      setParts([]);
    } finally {
      setLoading(false);
    }
  };

  // Alterar quantidade de peças selecionadas
  const handlePartQuantityChange = (partId, quantity) => {
    const newSelectedParts = { ...selectedParts };

    if (quantity > 0) {
      newSelectedParts[partId] = quantity;
    } else {
      delete newSelectedParts[partId];
    }

    setSelectedParts(newSelectedParts);
  };

  // Cálculo de preços em tempo real
  useEffect(() => {
    const calculatePricing = async () => {
      const selectedPartsList = Object.entries(selectedParts);

      if (selectedPartsList.length === 0) {
        setPricing(null);
        return;
      }

      try {
        const itens = selectedPartsList.map(([partId, quantidade]) => {
          const part = parts.find((p) => p.id === partId);
          return {
            peca: { id: part.id, nome: part.nome, valor: part.valor },
            quantidade,
          };
        });

        const response = await axios.post(`${API_URL}/calcular`, { itens });
        setPricing(response.data);
      } catch {
        setPricing(null);
      }
    };

    const timeoutId = setTimeout(calculatePricing, 500);
    return () => clearTimeout(timeoutId);
  }, [selectedParts, parts, API_URL]);

  const getMaxQuantity = (part) =>
    part.nome.toLowerCase().includes("chassi") ? 1 : 4;

  const getTotalItems = () =>
    Object.values(selectedParts).reduce((sum, qty) => sum + qty, 0);

  // Finalizar compra
  const handlePurchase = async () => {
    if (!pricing || getTotalItems() === 0) return;

    try {
      const itens = Object.entries(selectedParts).map(
        ([partId, quantidade]) => {
          const part = parts.find((p) => p.id === partId);
          return {
            peca: { id: part.id, nome: part.nome, valor: part.valor },
            quantidade,
          };
        }
      );

      const valorTotal = (pricing.preco || 0) + (pricing.frete || 0);

      const response = await axios.post(`${API_URL}/pagar`, {
        itens,
        valor_total: valorTotal,
      });

      setPurchaseResult(response.data);
      setShowCartPage(true);
    } catch (error) {
      alert(
        `Erro ao finalizar compra: ${
          error.response?.data?.detail || error.message
        }`
      );
    }
  };

  if (showCartPage) {
    return (
      <CartPage
        pricing={pricing}
        selectedParts={selectedParts}
        parts={parts}
        onBack={onBackFromCart}
        purchaseResult={purchaseResult}
        setPurchaseResult={setPurchaseResult}
        getTotalItems={getTotalItems}
        setPurchaseLoading={() => {}}
        returnHome={restartApp}
      />
    );
  }

  return (
    <div className="app">
      <header className="header">
        <h1>🚗 Catálogo de Peças Automotivas</h1>
        <button className="cart" onClick={onOpenCart}>
          <span className="cart-icon">🛒</span>
          <span className="cart-count">{getTotalItems()}</span>
        </button>
      </header>

      <div className="main-content">
        <aside className="sidebar">
          <h2>Selecione um Carro</h2>
          <div className="car-list">
            {mockCarros.map((car, index) => (
              <div
                key={index}
                className={`car-card ${
                  selectedCar?.modelo === car.modelo ? "selected" : ""
                }`}
                onClick={() => handleCarSelect(car)}
              >
                <h3>{car.modelo}</h3>
                <p>Ano: {car.ano}</p>
              </div>
            ))}
          </div>

          {pricing && (
            <div className="pricing-summary">
              <h3>💰 Orçamento</h3>
              <div className="pricing-details">
                <div className="pricing-line">
                  <span>Subtotal:</span>
                  <span>
                    R${" "}
                    {(pricing.preco || 0).toLocaleString("pt-BR", {
                      minimumFractionDigits: 2,
                    })}
                  </span>
                </div>
                <div className="pricing-line">
                  <span>Frete:</span>
                  <span>
                    R${" "}
                    {(pricing.frete || 0).toLocaleString("pt-BR", {
                      minimumFractionDigits: 2,
                    })}
                  </span>
                </div>
                <div className="pricing-total">
                  <span>Total:</span>
                  <span>
                    R${" "}
                    {(
                      (pricing.preco || 0) + (pricing.frete || 0)
                    ).toLocaleString("pt-BR", { minimumFractionDigits: 2 })}
                  </span>
                </div>

                {getTotalItems() > 0 && (
                  <button
                    className="purchase-button"
                    onClick={onOpenCart}
                    style={{
                      width: "100%",
                      padding: "12px",
                      marginTop: "15px",
                      backgroundColor: "#28a745",
                      color: "white",
                      border: "none",
                      borderRadius: "8px",
                      fontSize: "16px",
                      fontWeight: "bold",
                      cursor: "pointer",
                    }}
                  >
                    🛒 Ver carrinho
                  </button>
                )}
              </div>
            </div>
          )}
        </aside>

        <main className="content">
          {!selectedCar ? (
            <div
              style={{ textAlign: "center", padding: "3rem", color: "#666" }}
            >
              <h2>👈 Selecione um carro na barra lateral</h2>
              <p>Escolha um modelo para ver as peças disponíveis</p>
            </div>
          ) : (
            <div>
              <h1>
                Peças para {selectedCar.modelo.toUpperCase()} ({selectedCar.ano}
                )
              </h1>

              {loading ? (
                <div className="loading">
                  <p>🔄 Carregando peças...</p>
                </div>
              ) : error ? (
                <div className="error">
                  <p>{error}</p>
                  <small>Verifique se o P-Api está rodando em: {API_URL}</small>
                </div>
              ) : (
                <div className="parts-list">
                  <h2>Peças Disponíveis ({parts.length})</h2>
                  <p style={{ color: "#666", marginBottom: "1rem" }}>
                    Selecione as peças e quantidades desejadas. O preço será
                    calculado em tempo real.
                  </p>

                  <div className="parts-grid">
                    {parts.map((part) => {
                      const maxQty = getMaxQuantity(part);
                      const currentQty = selectedParts[part.id] || 0;

                      return (
                        <div key={part.id} className="part-card interactive">
                          <h4>{part.nome}</h4>
                          <div className="price">
                            R${" "}
                            {part.valor.toLocaleString("pt-BR", {
                              minimumFractionDigits: 2,
                            })}
                          </div>
                          <div className="id">ID: {part.id}</div>

                          <div className="quantity-controls">
                            <label>Quantidade:</label>
                            <div className="quantity-input">
                              <button
                                onClick={() =>
                                  handlePartQuantityChange(
                                    part.id,
                                    Math.max(0, currentQty - 1)
                                  )
                                }
                                disabled={currentQty <= 0}
                                className="qty-btn"
                              >
                                -
                              </button>
                              <span className="qty-display">{currentQty}</span>
                              <button
                                onClick={() =>
                                  handlePartQuantityChange(
                                    part.id,
                                    Math.min(maxQty, currentQty + 1)
                                  )
                                }
                                disabled={currentQty >= maxQty}
                                className="qty-btn"
                              >
                                +
                              </button>
                            </div>
                            {maxQty === 1 && (
                              <small
                                style={{ color: "#999", fontSize: "0.8rem" }}
                              >
                                Máximo: 1 unidade
                              </small>
                            )}
                            {currentQty > 0 && (
                              <div className="item-total">
                                Subtotal: R${" "}
                                {(part.valor * currentQty).toLocaleString(
                                  "pt-BR",
                                  { minimumFractionDigits: 2 }
                                )}
                              </div>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}
            </div>
          )}
        </main>
      </div>
    </div>
  );
}

export default App;
