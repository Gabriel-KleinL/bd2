-- ========================================================================
-- BANCO DE DADOS DO AVALIADOR DE SIMULAÇÕES GRAVITACIONAIS
-- ========================================================================
-- Este schema armazena dados de simulações completas para avaliação científica
-- Apenas simulações finalizadas com 3+ corpos são importadas

-- ========================================================================
-- 1. MODELO LÓGICO DO AVALIADOR
-- ========================================================================
/*
TABELAS:
- Simulacoes_Avaliadas: Dados principais das simulações importadas
- Resultados_Finais: Estado final de cada simulação (última iteração)
- Corpos_Finais: Corpos remanescentes no estado final
- Historico_Exportacoes: Controle de exportações do gerador para o avaliador
- Status_Avaliacoes: Avaliações científicas realizadas

RELACIONAMENTOS:
- Simulacoes_Avaliadas (1) -----> (1) Resultados_Finais
- Resultados_Finais (1) -----> (N) Corpos_Finais
- Simulacoes_Avaliadas (1) -----> (N) Historico_Exportacoes
- Simulacoes_Avaliadas (1) -----> (0..N) Status_Avaliacoes
*/

-- ========================================================================
-- 2. MODELO FÍSICO DO AVALIADOR
-- ========================================================================
/*
Simulacoes_Avaliadas:
  - NumSimulacao (INT, PK) - Mesmo ID do gerador
  - DataSimulacao (DATETIME)
  - DataImportacao (DATETIME)
  - QtdCorposInicial (INT)
  - QtdCorposFinais (INT) - Quantidade de corpos que sobreviveram
  - NumInteracoes (INT)
  - TempoInteracoes (INT)
  - StatusAvaliacao (ENUM: 'PENDENTE', 'EM_ANALISE', 'INTERESSE_CIENTIFICO', 'SEM_INTERESSE')

Resultados_Finais:
  - NumSimulacao (INT, PK, FK -> Simulacoes_Avaliadas)
  - NumIteracao (INT) - Última iteração executada
  - TempoExecucao (INT) - Tempo total de execução

Corpos_Finais:
  - IdCorpo (INT, PK, AUTO_INCREMENT)
  - NumSimulacao (INT, FK -> Resultados_Finais)
  - NomeCorpo (VARCHAR(100))
  - MassaCorpo (FLOAT)
  - PosX (FLOAT)
  - PosY (FLOAT)
  - VelX (FLOAT)
  - VelY (FLOAT)
  - DensidadeCorpo (FLOAT)
  - EnergiaTotal (FLOAT) - Calculada: energia cinética + potencial
  - MomentoAngular (FLOAT) - Conservação do momento angular

Historico_Exportacoes:
  - IdExportacao (INT, PK, AUTO_INCREMENT)
  - NumSimulacao (INT, FK -> Simulacoes_Avaliadas)
  - DataTentativa (DATETIME)
  - StatusExportacao (ENUM: 'SUCESSO', 'FALHA', 'PARCIAL')
  - MensagemErro (TEXT)
  - QtdCorposExportados (INT)

Status_Avaliacoes:
  - IdAvaliacao (INT, PK, AUTO_INCREMENT)
  - NumSimulacao (INT, FK -> Simulacoes_Avaliadas)
  - DataAvaliacao (DATETIME)
  - Avaliador (VARCHAR(100))
  - NotaInteresse (INT) - 1 a 5
  - Observacoes (TEXT)
*/

-- ========================================================================
-- 3. CRIAÇÃO DO SCHEMA E TABELAS
-- ========================================================================

-- Criar o schema/database do avaliador
DROP DATABASE IF EXISTS AvaliacaoSimulacoes;
CREATE DATABASE AvaliacaoSimulacoes;
USE AvaliacaoSimulacoes;

-- -----------------------------------------------------------------------
-- Tabela: Simulacoes_Avaliadas
-- -----------------------------------------------------------------------
CREATE TABLE Simulacoes_Avaliadas (
    NumSimulacao INT PRIMARY KEY,
    DataSimulacao DATETIME NOT NULL,
    DataImportacao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    QtdCorposInicial INT NOT NULL,
    QtdCorposFinais INT NOT NULL,
    NumInteracoes INT NOT NULL,
    TempoInteracoes INT NOT NULL,
    StatusAvaliacao ENUM('PENDENTE', 'EM_ANALISE', 'INTERESSE_CIENTIFICO', 'SEM_INTERESSE')
        DEFAULT 'PENDENTE',

    CONSTRAINT chk_qtd_corpos_inicial CHECK (QtdCorposInicial >= 200),
    CONSTRAINT chk_qtd_corpos_finais CHECK (QtdCorposFinais >= 3),
    CONSTRAINT chk_num_interacoes CHECK (NumInteracoes BETWEEN 100000 AND 500000),
    CONSTRAINT chk_tempo CHECK (TempoInteracoes > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
COMMENT='Armazena simulações completas importadas do gerador para avaliação científica';

-- -----------------------------------------------------------------------
-- Tabela: Resultados_Finais
-- -----------------------------------------------------------------------
CREATE TABLE Resultados_Finais (
    NumSimulacao INT PRIMARY KEY,
    NumIteracao INT NOT NULL,
    TempoExecucao INT NOT NULL,

    CONSTRAINT fk_resultados_finais_simulacao
        FOREIGN KEY (NumSimulacao)
        REFERENCES Simulacoes_Avaliadas(NumSimulacao)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
COMMENT='Estado final (última iteração) de cada simulação avaliada';

-- -----------------------------------------------------------------------
-- Tabela: Corpos_Finais
-- -----------------------------------------------------------------------
CREATE TABLE Corpos_Finais (
    IdCorpo INT PRIMARY KEY AUTO_INCREMENT,
    NumSimulacao INT NOT NULL,
    NomeCorpo VARCHAR(100) NOT NULL,
    MassaCorpo FLOAT NOT NULL,
    PosX FLOAT NOT NULL,
    PosY FLOAT NOT NULL,
    VelX FLOAT NOT NULL,
    VelY FLOAT NOT NULL,
    DensidadeCorpo FLOAT NOT NULL,
    EnergiaTotal FLOAT DEFAULT NULL,
    MomentoAngular FLOAT DEFAULT NULL,

    CONSTRAINT fk_corpos_finais_resultado
        FOREIGN KEY (NumSimulacao)
        REFERENCES Resultados_Finais(NumSimulacao)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_massa_final CHECK (MassaCorpo > 0),
    CONSTRAINT chk_densidade_final CHECK (DensidadeCorpo > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
COMMENT='Corpos remanescentes no estado final das simulações';

-- -----------------------------------------------------------------------
-- Tabela: Historico_Exportacoes
-- -----------------------------------------------------------------------
CREATE TABLE Historico_Exportacoes (
    IdExportacao INT PRIMARY KEY AUTO_INCREMENT,
    NumSimulacao INT NOT NULL,
    DataTentativa DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    StatusExportacao ENUM('SUCESSO', 'FALHA', 'PARCIAL') NOT NULL,
    MensagemErro TEXT,
    QtdCorposExportados INT DEFAULT 0,

    CONSTRAINT fk_historico_simulacao
        FOREIGN KEY (NumSimulacao)
        REFERENCES Simulacoes_Avaliadas(NumSimulacao)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
COMMENT='Histórico de tentativas de exportação do gerador para o avaliador';

-- -----------------------------------------------------------------------
-- Tabela: Status_Avaliacoes
-- -----------------------------------------------------------------------
CREATE TABLE Status_Avaliacoes (
    IdAvaliacao INT PRIMARY KEY AUTO_INCREMENT,
    NumSimulacao INT NOT NULL,
    DataAvaliacao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Avaliador VARCHAR(100) NOT NULL,
    NotaInteresse INT NOT NULL,
    Observacoes TEXT,

    CONSTRAINT fk_status_simulacao
        FOREIGN KEY (NumSimulacao)
        REFERENCES Simulacoes_Avaliadas(NumSimulacao)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_nota CHECK (NotaInteresse BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
COMMENT='Avaliações científicas realizadas sobre as simulações';

-- ========================================================================
-- 4. ÍNDICES PARA OTIMIZAÇÃO
-- ========================================================================

-- Índices para consultas frequentes
CREATE INDEX idx_simulacoes_data_importacao ON Simulacoes_Avaliadas(DataImportacao);
CREATE INDEX idx_simulacoes_status ON Simulacoes_Avaliadas(StatusAvaliacao);
CREATE INDEX idx_simulacoes_qtd_corpos ON Simulacoes_Avaliadas(QtdCorposFinais);

CREATE INDEX idx_corpos_finais_simulacao ON Corpos_Finais(NumSimulacao);
CREATE INDEX idx_corpos_finais_nome ON Corpos_Finais(NomeCorpo);
CREATE INDEX idx_corpos_finais_massa ON Corpos_Finais(MassaCorpo);

CREATE INDEX idx_historico_status ON Historico_Exportacoes(StatusExportacao);
CREATE INDEX idx_historico_data ON Historico_Exportacoes(DataTentativa);

CREATE INDEX idx_avaliacoes_nota ON Status_Avaliacoes(NotaInteresse);
CREATE INDEX idx_avaliacoes_data ON Status_Avaliacoes(DataAvaliacao);

-- ========================================================================
-- 5. VIEWS ÚTEIS
-- ========================================================================

-- View completa de simulações com suas avaliações
CREATE VIEW vw_Simulacoes_Completas AS
SELECT
    s.NumSimulacao,
    s.DataSimulacao,
    s.DataImportacao,
    s.QtdCorposInicial,
    s.QtdCorposFinais,
    s.NumInteracoes,
    s.TempoInteracoes,
    s.StatusAvaliacao,
    r.NumIteracao AS IteracaoFinal,
    r.TempoExecucao,
    COUNT(c.IdCorpo) AS QtdCorposRegistrados,
    AVG(sa.NotaInteresse) AS MediaAvaliacao,
    COUNT(sa.IdAvaliacao) AS QtdAvaliacoes
FROM Simulacoes_Avaliadas s
LEFT JOIN Resultados_Finais r ON s.NumSimulacao = r.NumSimulacao
LEFT JOIN Corpos_Finais c ON s.NumSimulacao = c.NumSimulacao
LEFT JOIN Status_Avaliacoes sa ON s.NumSimulacao = sa.NumSimulacao
GROUP BY s.NumSimulacao, s.DataSimulacao, s.DataImportacao,
         s.QtdCorposInicial, s.QtdCorposFinais, s.NumInteracoes,
         s.TempoInteracoes, s.StatusAvaliacao, r.NumIteracao, r.TempoExecucao;

-- View de simulações com interesse científico
CREATE VIEW vw_Simulacoes_Interesse_Cientifico AS
SELECT
    s.*,
    AVG(sa.NotaInteresse) AS MediaAvaliacao
FROM Simulacoes_Avaliadas s
INNER JOIN Status_Avaliacoes sa ON s.NumSimulacao = sa.NumSimulacao
WHERE s.StatusAvaliacao = 'INTERESSE_CIENTIFICO'
GROUP BY s.NumSimulacao
HAVING AVG(sa.NotaInteresse) >= 3
ORDER BY MediaAvaliacao DESC;

-- View de simulações pendentes de avaliação
CREATE VIEW vw_Simulacoes_Pendentes AS
SELECT
    s.*,
    r.NumIteracao AS IteracaoFinal,
    COUNT(c.IdCorpo) AS QtdCorposFinais,
    DATEDIFF(NOW(), s.DataImportacao) AS DiasDesdeImportacao
FROM Simulacoes_Avaliadas s
INNER JOIN Resultados_Finais r ON s.NumSimulacao = r.NumSimulacao
LEFT JOIN Corpos_Finais c ON s.NumSimulacao = c.NumSimulacao
WHERE s.StatusAvaliacao = 'PENDENTE'
GROUP BY s.NumSimulacao
ORDER BY s.DataImportacao ASC;

-- ========================================================================
-- 6. STORED PROCEDURES AUXILIARES
-- ========================================================================

DELIMITER //

-- Procedure para marcar simulação como avaliada
CREATE PROCEDURE sp_AvaliarSimulacao(
    IN p_NumSimulacao INT,
    IN p_Avaliador VARCHAR(100),
    IN p_NotaInteresse INT,
    IN p_Observacoes TEXT
)
BEGIN
    DECLARE v_status VARCHAR(30);

    -- Validar nota
    IF p_NotaInteresse < 1 OR p_NotaInteresse > 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nota de interesse deve estar entre 1 e 5';
    END IF;

    -- Inserir avaliação
    INSERT INTO Status_Avaliacoes (NumSimulacao, Avaliador, NotaInteresse, Observacoes)
    VALUES (p_NumSimulacao, p_Avaliador, p_NotaInteresse, p_Observacoes);

    -- Atualizar status da simulação baseado na nota
    IF p_NotaInteresse >= 4 THEN
        SET v_status = 'INTERESSE_CIENTIFICO';
    ELSEIF p_NotaInteresse >= 2 THEN
        SET v_status = 'EM_ANALISE';
    ELSE
        SET v_status = 'SEM_INTERESSE';
    END IF;

    UPDATE Simulacoes_Avaliadas
    SET StatusAvaliacao = v_status
    WHERE NumSimulacao = p_NumSimulacao;

    SELECT CONCAT('Simulação ', p_NumSimulacao, ' avaliada com sucesso. Status: ', v_status) AS Resultado;
END //

-- Procedure para obter estatísticas de uma simulação
CREATE PROCEDURE sp_EstatisticasSimulacao(
    IN p_NumSimulacao INT
)
BEGIN
    SELECT
        s.NumSimulacao,
        s.DataSimulacao,
        s.DataImportacao,
        s.QtdCorposInicial,
        s.QtdCorposFinais,
        s.NumInteracoes,
        s.StatusAvaliacao,
        r.NumIteracao AS IteracaoFinal,
        COUNT(c.IdCorpo) AS QtdCorposRegistrados,
        AVG(c.MassaCorpo) AS MassaMediaCorpos,
        SUM(c.MassaCorpo) AS MassaTotalSistema,
        AVG(sa.NotaInteresse) AS MediaAvaliacoes,
        COUNT(sa.IdAvaliacao) AS TotalAvaliacoes
    FROM Simulacoes_Avaliadas s
    LEFT JOIN Resultados_Finais r ON s.NumSimulacao = r.NumSimulacao
    LEFT JOIN Corpos_Finais c ON s.NumSimulacao = c.NumSimulacao
    LEFT JOIN Status_Avaliacoes sa ON s.NumSimulacao = sa.NumSimulacao
    WHERE s.NumSimulacao = p_NumSimulacao
    GROUP BY s.NumSimulacao;
END //

DELIMITER ;

-- ========================================================================
-- FIM DO SCHEMA DO AVALIADOR
-- ========================================================================
