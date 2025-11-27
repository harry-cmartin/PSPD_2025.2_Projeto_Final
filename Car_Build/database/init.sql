-- Criar tabela de carros
CREATE TABLE IF NOT EXISTS carros (
    id SERIAL PRIMARY KEY,
    modelo VARCHAR(50) NOT NULL UNIQUE,
    ano INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Criar tabela de peças
CREATE TABLE IF NOT EXISTS pecas (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    valor DECIMAL(10,2) NOT NULL,
    modelo_fk VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (modelo_fk) REFERENCES carros(modelo) ON DELETE CASCADE
);

-- Criar índices para performance
CREATE INDEX IF NOT EXISTS idx_pecas_modelo_fk ON pecas(modelo_fk);
CREATE INDEX IF NOT EXISTS idx_carros_modelo ON carros(modelo);

-- Popular tabela de carros
INSERT INTO carros (modelo, ano) VALUES 
    ('fusca', 2014),
    ('civic', 2023),
    ('corolla', 2020)
ON CONFLICT (modelo) DO NOTHING;

-- Popular tabela de peças
-- Peças do Fusca
INSERT INTO pecas (nome, valor, modelo_fk) VALUES 
    ('Chassi', 5000.00, 'fusca'),
    ('Motor 1.6', 3500.00, 'fusca'),
    ('Rodas Aro 14', 800.00, 'fusca'),
    ('Farol Dianteiro', 150.00, 'fusca'),
    ('Parachoque Traseiro', 200.00, 'fusca'),
    ('Capô', 350.00, 'fusca')
ON CONFLICT DO NOTHING;

-- Peças do Civic
INSERT INTO pecas (nome, valor, modelo_fk) VALUES 
    ('Chassi', 8000.00, 'civic'),
    ('Motor 2.0 VTEC', 6500.00, 'civic'),
    ('Rodas Aro 16', 1200.00, 'civic'),
    ('Farol LED', 350.00, 'civic'),
    ('Parachoque Esportivo', 450.00, 'civic'),
    ('Capô Esportivo', 600.00, 'civic'),
    ('Spoiler', 300.00, 'civic')
ON CONFLICT DO NOTHING;

-- Peças do Corolla
INSERT INTO pecas (nome, valor, modelo_fk) VALUES 
    ('Chassi', 7500.00, 'corolla'),
    ('Motor 1.8 Hybrid', 7000.00, 'corolla'),
    ('Rodas Aro 15', 900.00, 'corolla'),
    ('Farol Xenon', 280.00, 'corolla'),
    ('Parachoque Híbrido', 400.00, 'corolla'),
    ('Capô Aerodinâmico', 500.00, 'corolla'),
    ('Sistema Híbrido', 2000.00, 'corolla')
ON CONFLICT DO NOTHING;

-- Criar view para consultas otimizadas
CREATE OR REPLACE VIEW vw_pecas_por_modelo AS 
SELECT 
    p.id,
    p.nome,
    p.valor,
    p.modelo_fk as modelo,
    c.ano
FROM pecas p
JOIN carros c ON p.modelo_fk = c.modelo;

-- Função para buscar peças por modelo
CREATE OR REPLACE FUNCTION get_pecas_por_modelo(modelo_param VARCHAR(50))
RETURNS TABLE(id INTEGER, nome VARCHAR(100), valor DECIMAL(10,2)) 
AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.nome, p.valor
    FROM pecas p
    WHERE LOWER(p.modelo_fk) = LOWER(modelo_param);
END;
$$ LANGUAGE plpgsql;

-- Log de inicialização
INSERT INTO carros (modelo, ano) VALUES ('_log_init_', EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::INTEGER)
ON CONFLICT (modelo) DO UPDATE SET ano = EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::INTEGER;

-- Exibir estatísticas finais
DO $$
DECLARE
    total_carros INTEGER;
    total_pecas INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_carros FROM carros WHERE modelo != '_log_init_';
    SELECT COUNT(*) INTO total_pecas FROM pecas;
    
    RAISE NOTICE 'Database initialized successfully!';
    RAISE NOTICE 'Total carros: %', total_carros;
    RAISE NOTICE 'Total pecas: %', total_pecas;
END $$;