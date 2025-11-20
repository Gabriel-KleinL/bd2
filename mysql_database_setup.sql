-- ========================================================================
-- BANCO DE DADOS MYSQL - SIMULAÇÃO DE CORPOS
-- ========================================================================

-- ========================================================================
-- 1. MODELO LÓGICO
-- ========================================================================
/*
TABELAS:
- Simulacao: Armazena informações sobre cada simulação
- Resultados: Armazena os resultados de cada iteração de uma simulação
- Corpos: Armazena os corpos celestes de cada resultado

RELACIONAMENTOS:
- Simulacao (1) -----> (N) Resultados
- Resultados (1) -----> (N) Corpos
*/

-- ========================================================================
-- 2. MODELO FÍSICO
-- ========================================================================
/*
Simulacao:
  - NumSimulacao (INT, PK)
  - DataSimulacao (VARCHAR(50))
  - QtdCorposInicial (INT)
  - NumInteracoes (INT)
  - TempoInteracoes (INT)

Resultados:
  - NumSimulacao (INT, PK, FK -> Simulacao)
  - NumIteracao (INT, PK)

Corpos:
  - IdCorpo (INT, PK, AUTO_INCREMENT)
  - NumSimulacao (INT, FK -> Resultados)
  - NumIteracao (INT, FK -> Resultados)
  - NomeCorpo (VARCHAR(100))
  - MassaCorpo (FLOAT)
  - PosX (FLOAT)
  - PosY (FLOAT)
  - VelX (FLOAT)
  - VelY (FLOAT)
  - DensidadeCorpo (FLOAT)
*/

-- ========================================================================
-- 3. DEFINIÇÃO DAS CHAVES
-- ========================================================================
/*
CHAVES PRIMÁRIAS (PK):
- Simulacao: NumSimulacao
- Resultados: (NumSimulacao, NumIteracao) - Chave composta
- Corpos: IdCorpo - Chave surrogate para facilitar operações

CHAVES ESTRANGEIRAS (FK):
- Resultados.NumSimulacao -> Simulacao.NumSimulacao
- Corpos.(NumSimulacao, NumIteracao) -> Resultados.(NumSimulacao, NumIteracao)

ÍNDICES:
- Índices automáticos nas PKs
- Índice em Corpos(NumSimulacao, NumIteracao) para FK
- Índice em Corpos(NomeCorpo) para buscas por nome
*/

-- ========================================================================
-- 4. SCRIPT DE CRIAÇÃO DO BANCO
-- ========================================================================

-- Criar o banco de dados
DROP DATABASE IF EXISTS SimulacaoCorpos;
CREATE DATABASE SimulacaoCorpos;
USE SimulacaoCorpos;

-- Tabela Simulacao
CREATE TABLE Simulacao (
    NumSimulacao INT PRIMARY KEY AUTO_INCREMENT,
    DataSimulacao VARCHAR(50) NOT NULL,
    QtdCorposInicial INT NOT NULL,
    NumInteracoes INT NOT NULL,
    TempoInteracoes INT NOT NULL,
    CONSTRAINT chk_qtd_corpos CHECK (QtdCorposInicial > 0),
    CONSTRAINT chk_num_interacoes CHECK (NumInteracoes > 0),
    CONSTRAINT chk_tempo CHECK (TempoInteracoes > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabela Resultados
CREATE TABLE Resultados (
    NumSimulacao INT NOT NULL,
    NumIteracao INT NOT NULL,
    PRIMARY KEY (NumSimulacao, NumIteracao),
    CONSTRAINT fk_resultados_simulacao
        FOREIGN KEY (NumSimulacao)
        REFERENCES Simulacao(NumSimulacao)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabela Corpos
CREATE TABLE Corpos (
    IdCorpo INT PRIMARY KEY AUTO_INCREMENT,
    NumSimulacao INT NOT NULL,
    NumIteracao INT NOT NULL,
    NomeCorpo VARCHAR(100) NOT NULL,
    MassaCorpo FLOAT NOT NULL,
    PosX FLOAT NOT NULL,
    PosY FLOAT NOT NULL,
    VelX FLOAT NOT NULL,
    VelY FLOAT NOT NULL,
    DensidadeCorpo FLOAT NOT NULL,
    CONSTRAINT fk_corpos_resultados
        FOREIGN KEY (NumSimulacao, NumIteracao)
        REFERENCES Resultados(NumSimulacao, NumIteracao)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_massa CHECK (MassaCorpo > 0),
    CONSTRAINT chk_densidade CHECK (DensidadeCorpo > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Criar índices adicionais para melhorar performance
CREATE INDEX idx_corpos_nome ON Corpos(NomeCorpo);
CREATE INDEX idx_resultados_iteracao ON Resultados(NumIteracao);

-- ========================================================================
-- 5. DADOS DE EXEMPLO (OPCIONAL)
-- ========================================================================

-- Inserir simulação de exemplo
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES ('2025-11-20 10:00:00', 3, 100, 3600);

-- Inserir resultados da iteração 0 (estado inicial)
INSERT INTO Resultados (NumSimulacao, NumIteracao)
VALUES (1, 0);

-- Inserir corpos da iteração 0
INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (1, 0, 'Sol', 1.989e30, 0.0, 0.0, 0.0, 0.0, 1408.0),
    (1, 0, 'Terra', 5.972e24, 1.496e11, 0.0, 0.0, 29780.0, 5514.0),
    (1, 0, 'Lua', 7.342e22, 1.496e11 + 3.844e8, 0.0, 0.0, 29780.0 + 1022.0, 3344.0);

-- Inserir resultados da iteração 50
INSERT INTO Resultados (NumSimulacao, NumIteracao)
VALUES (1, 50);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (1, 50, 'Sol', 1.989e30, 1000.0, 500.0, 10.0, 5.0, 1408.0),
    (1, 50, 'Terra', 5.972e24, 1.5e11, 2.0e10, 15000.0, 29000.0, 5514.0),
    (1, 50, 'Lua', 7.342e22, 1.51e11, 2.01e10, 15500.0, 29500.0, 3344.0);

-- Inserir resultados da iteração 100 (última)
INSERT INTO Resultados (NumSimulacao, NumIteracao)
VALUES (1, 100);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (1, 100, 'Sol', 1.989e30, 2000.0, 1000.0, 20.0, 10.0, 1408.0),
    (1, 100, 'Terra', 5.972e24, -1.5e11, 1.0e10, -10000.0, 25000.0, 5514.0),
    (1, 100, 'Lua', 7.342e22, -1.49e11, 1.01e10, -9800.0, 25800.0, 3344.0);

-- ========================================================================
-- 6. CONSULTAS SQL (SELECTS) SOLICITADAS
-- ========================================================================

-- -----------------------------------------------------------------------
-- 6.1. Listar todos os resultados de uma determinada simulação
-- -----------------------------------------------------------------------
-- Parâmetro: @NumSimulacao

SELECT
    r.NumSimulacao,
    r.NumIteracao,
    s.DataSimulacao,
    COUNT(c.IdCorpo) AS QtdCorpos
FROM Resultados r
INNER JOIN Simulacao s ON r.NumSimulacao = s.NumSimulacao
LEFT JOIN Corpos c ON r.NumSimulacao = c.NumSimulacao
                   AND r.NumIteracao = c.NumIteracao
WHERE r.NumSimulacao = 1  -- Substituir pelo número da simulação desejada
GROUP BY r.NumSimulacao, r.NumIteracao, s.DataSimulacao
ORDER BY r.NumIteracao;

-- -----------------------------------------------------------------------
-- 6.2. Dado um determinado resultado, listar os corpos do resultado
-- -----------------------------------------------------------------------
-- Parâmetros: @NumSimulacao, @NumIteracao

SELECT
    c.IdCorpo,
    c.NomeCorpo,
    c.MassaCorpo,
    c.PosX,
    c.PosY,
    c.VelX,
    c.VelY,
    c.DensidadeCorpo,
    SQRT(POWER(c.PosX, 2) + POWER(c.PosY, 2)) AS DistanciaOrigem,
    SQRT(POWER(c.VelX, 2) + POWER(c.VelY, 2)) AS VelocidadeTotal
FROM Corpos c
WHERE c.NumSimulacao = 1     -- Substituir pelo número da simulação
  AND c.NumIteracao = 0      -- Substituir pelo número da iteração
ORDER BY c.NomeCorpo;

-- -----------------------------------------------------------------------
-- 6.3. Listar todos os resultados de uma simulação, com os respectivos corpos
-- -----------------------------------------------------------------------
-- Parâmetro: @NumSimulacao

SELECT
    r.NumIteracao,
    c.NomeCorpo,
    c.MassaCorpo,
    c.PosX,
    c.PosY,
    c.VelX,
    c.VelY,
    c.DensidadeCorpo
FROM Resultados r
INNER JOIN Corpos c ON r.NumSimulacao = c.NumSimulacao
                    AND r.NumIteracao = c.NumIteracao
WHERE r.NumSimulacao = 1     -- Substituir pelo número da simulação
ORDER BY r.NumIteracao, c.NomeCorpo;

-- -----------------------------------------------------------------------
-- 6.4. Informar a quantidade de resultados para uma determinada simulação
-- -----------------------------------------------------------------------
-- Parâmetro: @NumSimulacao

SELECT
    s.NumSimulacao,
    s.DataSimulacao,
    COUNT(r.NumIteracao) AS QtdResultados
FROM Simulacao s
LEFT JOIN Resultados r ON s.NumSimulacao = r.NumSimulacao
WHERE s.NumSimulacao = 1     -- Substituir pelo número da simulação
GROUP BY s.NumSimulacao, s.DataSimulacao;

-- -----------------------------------------------------------------------
-- 6.5. Informar a quantidade final de corpos de uma simulação
-- -----------------------------------------------------------------------
-- Parâmetro: @NumSimulacao
-- (Considera a última iteração como "final")

SELECT
    s.NumSimulacao,
    s.DataSimulacao,
    MAX(r.NumIteracao) AS UltimaIteracao,
    COUNT(c.IdCorpo) AS QtdCorposFinais
FROM Simulacao s
INNER JOIN Resultados r ON s.NumSimulacao = r.NumSimulacao
LEFT JOIN Corpos c ON r.NumSimulacao = c.NumSimulacao
                   AND r.NumIteracao = c.NumIteracao
WHERE s.NumSimulacao = 1     -- Substituir pelo número da simulação
  AND r.NumIteracao = (
      SELECT MAX(r2.NumIteracao)
      FROM Resultados r2
      WHERE r2.NumSimulacao = s.NumSimulacao
  )
GROUP BY s.NumSimulacao, s.DataSimulacao;

-- -----------------------------------------------------------------------
-- 6.6. Listar os corpos do último resultado de uma simulação
-- -----------------------------------------------------------------------
-- Parâmetro: @NumSimulacao

SELECT
    c.IdCorpo,
    c.NumIteracao,
    c.NomeCorpo,
    c.MassaCorpo,
    c.PosX,
    c.PosY,
    c.VelX,
    c.VelY,
    c.DensidadeCorpo,
    SQRT(POWER(c.PosX, 2) + POWER(c.PosY, 2)) AS DistanciaOrigem,
    SQRT(POWER(c.VelX, 2) + POWER(c.VelY, 2)) AS VelocidadeTotal
FROM Corpos c
INNER JOIN (
    SELECT NumSimulacao, MAX(NumIteracao) AS MaxIteracao
    FROM Resultados
    WHERE NumSimulacao = 1   -- Substituir pelo número da simulação
    GROUP BY NumSimulacao
) ultimo ON c.NumSimulacao = ultimo.NumSimulacao
        AND c.NumIteracao = ultimo.MaxIteracao
ORDER BY c.NomeCorpo;

-- ========================================================================
-- 7. CONSULTAS ADICIONAIS ÚTEIS
-- ========================================================================

-- Listar todas as simulações
SELECT * FROM Simulacao;

-- Visão geral de uma simulação
SELECT
    s.NumSimulacao,
    s.DataSimulacao,
    s.QtdCorposInicial,
    s.NumInteracoes,
    s.TempoInteracoes,
    COUNT(DISTINCT r.NumIteracao) AS QtdResultadosGerados,
    MIN(r.NumIteracao) AS PrimeiraIteracao,
    MAX(r.NumIteracao) AS UltimaIteracao
FROM Simulacao s
LEFT JOIN Resultados r ON s.NumSimulacao = r.NumSimulacao
WHERE s.NumSimulacao = 1
GROUP BY s.NumSimulacao, s.DataSimulacao, s.QtdCorposInicial,
         s.NumInteracoes, s.TempoInteracoes;

-- Comparar posições de um corpo específico ao longo das iterações
SELECT
    c.NumIteracao,
    c.NomeCorpo,
    c.PosX,
    c.PosY,
    SQRT(POWER(c.PosX, 2) + POWER(c.PosY, 2)) AS DistanciaOrigem
FROM Corpos c
WHERE c.NumSimulacao = 1
  AND c.NomeCorpo = 'Terra'
ORDER BY c.NumIteracao;

-- ========================================================================
-- 8. STORED PROCEDURES (OPCIONAL)
-- ========================================================================

DELIMITER //

-- Procedure para criar uma nova simulação
CREATE PROCEDURE sp_CriarSimulacao(
    IN p_DataSimulacao VARCHAR(50),
    IN p_QtdCorposInicial INT,
    IN p_NumInteracoes INT,
    IN p_TempoInteracoes INT,
    OUT p_NumSimulacao INT
)
BEGIN
    INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
    VALUES (p_DataSimulacao, p_QtdCorposInicial, p_NumInteracoes, p_TempoInteracoes);

    SET p_NumSimulacao = LAST_INSERT_ID();
END //

-- Procedure para adicionar um resultado
CREATE PROCEDURE sp_AdicionarResultado(
    IN p_NumSimulacao INT,
    IN p_NumIteracao INT
)
BEGIN
    INSERT INTO Resultados (NumSimulacao, NumIteracao)
    VALUES (p_NumSimulacao, p_NumIteracao);
END //

-- Procedure para adicionar um corpo
CREATE PROCEDURE sp_AdicionarCorpo(
    IN p_NumSimulacao INT,
    IN p_NumIteracao INT,
    IN p_NomeCorpo VARCHAR(100),
    IN p_MassaCorpo FLOAT,
    IN p_PosX FLOAT,
    IN p_PosY FLOAT,
    IN p_VelX FLOAT,
    IN p_VelY FLOAT,
    IN p_DensidadeCorpo FLOAT
)
BEGIN
    INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo,
                        PosX, PosY, VelX, VelY, DensidadeCorpo)
    VALUES (p_NumSimulacao, p_NumIteracao, p_NomeCorpo, p_MassaCorpo,
            p_PosX, p_PosY, p_VelX, p_VelY, p_DensidadeCorpo);
END //

DELIMITER ;

-- ========================================================================
-- 9. VIEWS ÚTEIS
-- ========================================================================

-- View para facilitar consulta de corpos com informações da simulação
CREATE VIEW vw_CorposCompleto AS
SELECT
    s.NumSimulacao,
    s.DataSimulacao,
    r.NumIteracao,
    c.IdCorpo,
    c.NomeCorpo,
    c.MassaCorpo,
    c.PosX,
    c.PosY,
    c.VelX,
    c.VelY,
    c.DensidadeCorpo,
    SQRT(POWER(c.PosX, 2) + POWER(c.PosY, 2)) AS DistanciaOrigem,
    SQRT(POWER(c.VelX, 2) + POWER(c.VelY, 2)) AS VelocidadeTotal
FROM Simulacao s
INNER JOIN Resultados r ON s.NumSimulacao = r.NumSimulacao
INNER JOIN Corpos c ON r.NumSimulacao = c.NumSimulacao
                    AND r.NumIteracao = c.NumIteracao;

-- View para estatísticas de simulações
CREATE VIEW vw_EstatisticasSimulacao AS
SELECT
    s.NumSimulacao,
    s.DataSimulacao,
    s.QtdCorposInicial,
    s.NumInteracoes,
    s.TempoInteracoes,
    COUNT(DISTINCT r.NumIteracao) AS QtdResultadosGerados,
    MAX(r.NumIteracao) AS UltimaIteracao
FROM Simulacao s
LEFT JOIN Resultados r ON s.NumSimulacao = r.NumSimulacao
GROUP BY s.NumSimulacao, s.DataSimulacao, s.QtdCorposInicial,
         s.NumInteracoes, s.TempoInteracoes;

-- ========================================================================
-- FIM DO SCRIPT
-- ========================================================================
