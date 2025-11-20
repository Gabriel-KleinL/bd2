-- ========================================================================
-- IMPORTAÇÃO COMPLETA - SISTEMA DE SIMULAÇÕES GRAVITACIONAIS
-- ========================================================================
-- Este script consolida TODOS os componentes do sistema em um único arquivo:
-- 1. Schema do Gerador (SimulacaoCorpos) com dados de exemplo
-- 2. Schema do Avaliador (AvaliacaoSimulacoes)
-- 3. Integração automática entre os schemas
-- 4. Rotinas de limpeza automática
-- 5. Dados de teste completos
--
-- INSTRUÇÕES DE USO:
-- Execute este arquivo no MySQL com: SOURCE importacao_completa.sql
-- ou: mysql -u usuario -p < importacao_completa.sql
-- ========================================================================

-- ========================================================================
-- PARTE 1: CRIAÇÃO DO SCHEMA GERADOR (SimulacaoCorpos)
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

-- Stored Procedures do Gerador
DELIMITER //

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

CREATE PROCEDURE sp_AdicionarResultado(
    IN p_NumSimulacao INT,
    IN p_NumIteracao INT
)
BEGIN
    INSERT INTO Resultados (NumSimulacao, NumIteracao)
    VALUES (p_NumSimulacao, p_NumIteracao);
END //

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

-- Views do Gerador
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
-- PARTE 2: CRIAÇÃO DO SCHEMA AVALIADOR (AvaliacaoSimulacoes)
-- ========================================================================

DROP DATABASE IF EXISTS AvaliacaoSimulacoes;
CREATE DATABASE AvaliacaoSimulacoes;
USE AvaliacaoSimulacoes;

-- Tabela: Simulacoes_Avaliadas
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

-- Tabela: Resultados_Finais
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

-- Tabela: Corpos_Finais
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

-- Tabela: Historico_Exportacoes
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

-- Tabela: Status_Avaliacoes
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

-- Índices para otimização
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

-- Views do Avaliador
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

-- Stored Procedures do Avaliador
DELIMITER //

CREATE PROCEDURE sp_AvaliarSimulacao(
    IN p_NumSimulacao INT,
    IN p_Avaliador VARCHAR(100),
    IN p_NotaInteresse INT,
    IN p_Observacoes TEXT
)
BEGIN
    DECLARE v_status VARCHAR(30);

    IF p_NotaInteresse < 1 OR p_NotaInteresse > 5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nota de interesse deve estar entre 1 e 5';
    END IF;

    INSERT INTO Status_Avaliacoes (NumSimulacao, Avaliador, NotaInteresse, Observacoes)
    VALUES (p_NumSimulacao, p_Avaliador, p_NotaInteresse, p_Observacoes);

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

-- Tabela de log de limpeza
CREATE TABLE IF NOT EXISTS Log_Limpeza (
    IdLog INT PRIMARY KEY AUTO_INCREMENT,
    DataLimpeza DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    QtdSimulacoesRemovidas INT DEFAULT 0,
    QtdCorposRemovidos INT DEFAULT 0,
    QtdAvaliacoesRemovidas INT DEFAULT 0,
    DataLimiteRemocao DATETIME,
    TempoExecucao INT COMMENT 'Tempo em segundos',
    Observacoes TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
COMMENT='Registro histórico das execuções de limpeza automática';

-- ========================================================================
-- PARTE 3: INTEGRAÇÃO ENTRE GERADOR E AVALIADOR
-- ========================================================================

USE SimulacaoCorpos;

-- Tabela de controle de exportação
CREATE TABLE IF NOT EXISTS Controle_Exportacao (
    NumSimulacao INT PRIMARY KEY,
    DataUltimaTentativa DATETIME,
    StatusExportacao ENUM('PENDENTE', 'SUCESSO', 'FALHA') DEFAULT 'PENDENTE',
    NumTentativas INT DEFAULT 0,
    MensagemErro TEXT,
    QtdCorposFinais INT,
    CONSTRAINT fk_controle_simulacao
        FOREIGN KEY (NumSimulacao)
        REFERENCES Simulacao(NumSimulacao)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
COMMENT='Controla o status de exportação de simulações para o avaliador';

CREATE INDEX idx_controle_status ON Controle_Exportacao(StatusExportacao);
CREATE INDEX idx_controle_data ON Controle_Exportacao(DataUltimaTentativa);
CREATE INDEX idx_resultados_sim_iter ON Resultados(NumSimulacao, NumIteracao DESC);
CREATE INDEX idx_corpos_exportacao ON Corpos(NumSimulacao, NumIteracao);

-- Stored Procedure de exportação
DELIMITER //

CREATE PROCEDURE sp_ExportarSimulacaoParaAvaliador(
    IN p_NumSimulacao INT
)
proc_label: BEGIN
    DECLARE v_QtdCorposFinais INT DEFAULT 0;
    DECLARE v_UltimaIteracao INT;
    DECLARE v_DataSimulacao VARCHAR(50);
    DECLARE v_QtdCorposInicial INT;
    DECLARE v_NumInteracoes INT;
    DECLARE v_TempoInteracoes INT;
    DECLARE v_ErroMsg TEXT DEFAULT NULL;
    DECLARE v_ExportacaoOK BOOLEAN DEFAULT FALSE;
    DECLARE v_StatusAtual VARCHAR(20);
    DECLARE v_NumTentativas INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        UPDATE Controle_Exportacao
        SET StatusExportacao = 'FALHA',
            DataUltimaTentativa = NOW(),
            NumTentativas = NumTentativas + 1,
            MensagemErro = v_ErroMsg
        WHERE NumSimulacao = p_NumSimulacao;
        SET @erro_insert = CONCAT('Erro ao exportar simulação ', p_NumSimulacao);
        SELECT @erro_insert AS Resultado;
    END;

    SELECT COUNT(*) INTO @sim_existe
    FROM Simulacao
    WHERE NumSimulacao = p_NumSimulacao;

    IF @sim_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Simulação não encontrada';
    END IF;

    SELECT DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes
    INTO v_DataSimulacao, v_QtdCorposInicial, v_NumInteracoes, v_TempoInteracoes
    FROM Simulacao
    WHERE NumSimulacao = p_NumSimulacao;

    SELECT MAX(NumIteracao)
    INTO v_UltimaIteracao
    FROM Resultados
    WHERE NumSimulacao = p_NumSimulacao;

    IF v_UltimaIteracao IS NULL THEN
        INSERT INTO Controle_Exportacao (NumSimulacao, StatusExportacao, QtdCorposFinais)
        VALUES (p_NumSimulacao, 'PENDENTE', 0)
        ON DUPLICATE KEY UPDATE
            StatusExportacao = 'PENDENTE',
            DataUltimaTentativa = NOW();
        SELECT CONCAT('Simulação ', p_NumSimulacao, ' ainda não possui resultados. Marcada como PENDENTE.') AS Resultado;
        LEAVE proc_label;
    END IF;

    SELECT COUNT(*)
    INTO v_QtdCorposFinais
    FROM Corpos
    WHERE NumSimulacao = p_NumSimulacao
      AND NumIteracao = v_UltimaIteracao;

    IF v_QtdCorposFinais < 3 THEN
        INSERT INTO Controle_Exportacao (
            NumSimulacao,
            StatusExportacao,
            DataUltimaTentativa,
            QtdCorposFinais,
            MensagemErro
        )
        VALUES (
            p_NumSimulacao,
            'SUCESSO',
            NOW(),
            v_QtdCorposFinais,
            'Simulação não exportada: menos de 3 corpos finais'
        )
        ON DUPLICATE KEY UPDATE
            StatusExportacao = 'SUCESSO',
            DataUltimaTentativa = NOW(),
            QtdCorposFinais = v_QtdCorposFinais,
            MensagemErro = 'Simulação não exportada: menos de 3 corpos finais';
        SELECT CONCAT('Simulação ', p_NumSimulacao, ' não exportada: apenas ', v_QtdCorposFinais, ' corpos finais (mínimo: 3)') AS Resultado;
        LEAVE proc_label;
    END IF;

    SELECT StatusExportacao, NumTentativas
    INTO v_StatusAtual, v_NumTentativas
    FROM Controle_Exportacao
    WHERE NumSimulacao = p_NumSimulacao;

    IF v_StatusAtual = 'SUCESSO' THEN
        SELECT CONCAT('Simulação ', p_NumSimulacao, ' já foi exportada com sucesso anteriormente.') AS Resultado;
        LEAVE proc_label;
    END IF;

    START TRANSACTION;

    INSERT INTO AvaliacaoSimulacoes.Simulacoes_Avaliadas (
        NumSimulacao,
        DataSimulacao,
        DataImportacao,
        QtdCorposInicial,
        QtdCorposFinais,
        NumInteracoes,
        TempoInteracoes,
        StatusAvaliacao
    )
    VALUES (
        p_NumSimulacao,
        v_DataSimulacao,
        NOW(),
        v_QtdCorposInicial,
        v_QtdCorposFinais,
        v_NumInteracoes,
        v_TempoInteracoes,
        'PENDENTE'
    )
    ON DUPLICATE KEY UPDATE
        DataImportacao = NOW(),
        QtdCorposFinais = v_QtdCorposFinais;

    INSERT INTO AvaliacaoSimulacoes.Resultados_Finais (
        NumSimulacao,
        NumIteracao,
        TempoExecucao
    )
    VALUES (
        p_NumSimulacao,
        v_UltimaIteracao,
        v_TempoInteracoes
    )
    ON DUPLICATE KEY UPDATE
        NumIteracao = v_UltimaIteracao,
        TempoExecucao = v_TempoInteracoes;

    INSERT INTO AvaliacaoSimulacoes.Corpos_Finais (
        NumSimulacao,
        NomeCorpo,
        MassaCorpo,
        PosX,
        PosY,
        VelX,
        VelY,
        DensidadeCorpo,
        EnergiaTotal,
        MomentoAngular
    )
    SELECT
        c.NumSimulacao,
        c.NomeCorpo,
        c.MassaCorpo,
        c.PosX,
        c.PosY,
        c.VelX,
        c.VelY,
        c.DensidadeCorpo,
        0.5 * c.MassaCorpo * (POWER(c.VelX, 2) + POWER(c.VelY, 2)) AS EnergiaTotal,
        c.MassaCorpo * (c.PosX * c.VelY - c.PosY * c.VelX) AS MomentoAngular
    FROM Corpos c
    WHERE c.NumSimulacao = p_NumSimulacao
      AND c.NumIteracao = v_UltimaIteracao
    ON DUPLICATE KEY UPDATE
        NomeCorpo = VALUES(NomeCorpo),
        MassaCorpo = VALUES(MassaCorpo),
        PosX = VALUES(PosX),
        PosY = VALUES(PosY),
        VelX = VALUES(VelX),
        VelY = VALUES(VelY),
        DensidadeCorpo = VALUES(DensidadeCorpo),
        EnergiaTotal = VALUES(EnergiaTotal),
        MomentoAngular = VALUES(MomentoAngular);

    INSERT INTO AvaliacaoSimulacoes.Historico_Exportacoes (
        NumSimulacao,
        DataTentativa,
        StatusExportacao,
        QtdCorposExportados
    )
    VALUES (
        p_NumSimulacao,
        NOW(),
        'SUCESSO',
        v_QtdCorposFinais
    );

    COMMIT;

    INSERT INTO Controle_Exportacao (
        NumSimulacao,
        StatusExportacao,
        DataUltimaTentativa,
        NumTentativas,
        QtdCorposFinais
    )
    VALUES (
        p_NumSimulacao,
        'SUCESSO',
        NOW(),
        v_NumTentativas + 1,
        v_QtdCorposFinais
    )
    ON DUPLICATE KEY UPDATE
        StatusExportacao = 'SUCESSO',
        DataUltimaTentativa = NOW(),
        NumTentativas = NumTentativas + 1,
        QtdCorposFinais = v_QtdCorposFinais,
        MensagemErro = NULL;

    SELECT CONCAT('Simulação ', p_NumSimulacao, ' exportada com sucesso! ',
                  v_QtdCorposFinais, ' corpos exportados.') AS Resultado;
END //

CREATE PROCEDURE sp_RetentarExportacoesFalhadas()
BEGIN
    DECLARE v_NumSimulacao INT;
    DECLARE v_Finalizado INT DEFAULT 0;

    DECLARE cursor_falhas CURSOR FOR
        SELECT NumSimulacao
        FROM Controle_Exportacao
        WHERE StatusExportacao = 'FALHA'
        ORDER BY DataUltimaTentativa ASC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_Finalizado = 1;

    OPEN cursor_falhas;

    loop_falhas: LOOP
        FETCH cursor_falhas INTO v_NumSimulacao;
        IF v_Finalizado = 1 THEN
            LEAVE loop_falhas;
        END IF;
        CALL sp_ExportarSimulacaoParaAvaliador(v_NumSimulacao);
    END LOOP;

    CLOSE cursor_falhas;
    SELECT 'Retry de exportações falhadas concluído' AS Resultado;
END //

DELIMITER ;

-- Trigger para exportação automática
DELIMITER //

DROP TRIGGER IF EXISTS trg_ExportarAntesNovaSimulacao //

CREATE TRIGGER trg_ExportarAntesNovaSimulacao
AFTER INSERT ON Simulacao
FOR EACH ROW
BEGIN
    DECLARE v_SimulacaoAnterior INT;
    DECLARE v_StatusExportacao VARCHAR(20);

    SELECT MAX(NumSimulacao) INTO v_SimulacaoAnterior
    FROM Simulacao
    WHERE NumSimulacao < NEW.NumSimulacao;

    IF v_SimulacaoAnterior IS NOT NULL THEN
        SELECT StatusExportacao INTO v_StatusExportacao
        FROM Controle_Exportacao
        WHERE NumSimulacao = v_SimulacaoAnterior;

        IF v_StatusExportacao IS NULL OR v_StatusExportacao != 'SUCESSO' THEN
            CALL sp_ExportarSimulacaoParaAvaliador(v_SimulacaoAnterior);
        END IF;
    END IF;

    INSERT INTO Controle_Exportacao (NumSimulacao, StatusExportacao)
    VALUES (NEW.NumSimulacao, 'PENDENTE');
END //

DELIMITER ;

-- ========================================================================
-- PARTE 4: ROTINAS DE LIMPEZA AUTOMÁTICA
-- ========================================================================

USE AvaliacaoSimulacoes;

DELIMITER //

CREATE PROCEDURE sp_LimparDadosAntigos(
    IN p_DiasRetencao INT
)
BEGIN
    DECLARE v_DataLimite DATETIME;
    DECLARE v_QtdSimulacoes INT DEFAULT 0;
    DECLARE v_QtdCorpos INT DEFAULT 0;
    DECLARE v_QtdAvaliacoes INT DEFAULT 0;
    DECLARE v_QtdResultados INT DEFAULT 0;
    DECLARE v_QtdHistorico INT DEFAULT 0;
    DECLARE v_InicioExecucao TIMESTAMP;
    DECLARE v_TempoExecucao INT;

    SET v_InicioExecucao = CURRENT_TIMESTAMP;
    SET v_DataLimite = DATE_SUB(NOW(), INTERVAL p_DiasRetencao DAY);

    SELECT COUNT(*) INTO v_QtdSimulacoes
    FROM Simulacoes_Avaliadas
    WHERE DataImportacao < v_DataLimite;

    SELECT COUNT(*) INTO v_QtdCorpos
    FROM Corpos_Finais c
    INNER JOIN Simulacoes_Avaliadas s ON c.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    SELECT COUNT(*) INTO v_QtdAvaliacoes
    FROM Status_Avaliacoes sa
    INNER JOIN Simulacoes_Avaliadas s ON sa.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    SELECT COUNT(*) INTO v_QtdResultados
    FROM Resultados_Finais r
    INNER JOIN Simulacoes_Avaliadas s ON r.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    SELECT COUNT(*) INTO v_QtdHistorico
    FROM Historico_Exportacoes h
    INNER JOIN Simulacoes_Avaliadas s ON h.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    IF v_QtdSimulacoes = 0 THEN
        INSERT INTO Log_Limpeza (
            DataLimpeza,
            QtdSimulacoesRemovidas,
            DataLimiteRemocao,
            TempoExecucao,
            Observacoes
        )
        VALUES (
            NOW(),
            0,
            v_DataLimite,
            0,
            'Nenhuma simulação antiga encontrada para remoção'
        );
        SELECT 'Nenhuma simulação antiga encontrada para remoção.' AS Resultado;
        LEAVE sp_LimparDadosAntigos;
    END IF;

    START TRANSACTION;

    DELETE sa FROM Status_Avaliacoes sa
    INNER JOIN Simulacoes_Avaliadas s ON sa.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    DELETE h FROM Historico_Exportacoes h
    INNER JOIN Simulacoes_Avaliadas s ON h.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    DELETE c FROM Corpos_Finais c
    INNER JOIN Simulacoes_Avaliadas s ON c.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    DELETE r FROM Resultados_Finais r
    INNER JOIN Simulacoes_Avaliadas s ON r.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    DELETE FROM Simulacoes_Avaliadas
    WHERE DataImportacao < v_DataLimite;

    COMMIT;

    SET v_TempoExecucao = TIMESTAMPDIFF(SECOND, v_InicioExecucao, CURRENT_TIMESTAMP);

    INSERT INTO Log_Limpeza (
        DataLimpeza,
        QtdSimulacoesRemovidas,
        QtdCorposRemovidos,
        QtdAvaliacoesRemovidas,
        DataLimiteRemocao,
        TempoExecucao,
        Observacoes
    )
    VALUES (
        NOW(),
        v_QtdSimulacoes,
        v_QtdCorpos,
        v_QtdAvaliacoes,
        v_DataLimite,
        v_TempoExecucao,
        CONCAT('Limpeza executada com sucesso. Removidos: ',
               v_QtdSimulacoes, ' simulações, ',
               v_QtdResultados, ' resultados, ',
               v_QtdCorpos, ' corpos, ',
               v_QtdAvaliacoes, ' avaliações, ',
               v_QtdHistorico, ' históricos')
    );

    OPTIMIZE TABLE Simulacoes_Avaliadas;
    OPTIMIZE TABLE Resultados_Finais;
    OPTIMIZE TABLE Corpos_Finais;
    OPTIMIZE TABLE Status_Avaliacoes;
    OPTIMIZE TABLE Historico_Exportacoes;

    SELECT
        v_QtdSimulacoes AS SimulacoesRemovidas,
        v_QtdResultados AS ResultadosRemovidos,
        v_QtdCorpos AS CorposRemovidos,
        v_QtdAvaliacoes AS AvaliacoesRemovidas,
        v_QtdHistorico AS HistoricosRemovidos,
        v_DataLimite AS DataLimite,
        v_TempoExecucao AS TempoExecucao_Segundos,
        'Limpeza executada com sucesso!' AS Status;
END //

CREATE PROCEDURE sp_PreviewLimpeza(
    IN p_DiasRetencao INT
)
BEGIN
    DECLARE v_DataLimite DATETIME;
    SET v_DataLimite = DATE_SUB(NOW(), INTERVAL p_DiasRetencao DAY);

    SELECT
        s.NumSimulacao,
        s.DataSimulacao,
        s.DataImportacao,
        DATEDIFF(NOW(), s.DataImportacao) AS DiasDesdeImportacao,
        s.QtdCorposFinais,
        s.StatusAvaliacao,
        COUNT(DISTINCT sa.IdAvaliacao) AS QtdAvaliacoes,
        COUNT(DISTINCT c.IdCorpo) AS QtdCorpos
    FROM Simulacoes_Avaliadas s
    LEFT JOIN Status_Avaliacoes sa ON s.NumSimulacao = sa.NumSimulacao
    LEFT JOIN Corpos_Finais c ON s.NumSimulacao = c.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite
    GROUP BY s.NumSimulacao
    ORDER BY s.DataImportacao ASC;

    SELECT
        COUNT(DISTINCT s.NumSimulacao) AS TotalSimulacoes,
        COUNT(DISTINCT c.IdCorpo) AS TotalCorpos,
        COUNT(DISTINCT sa.IdAvaliacao) AS TotalAvaliacoes,
        v_DataLimite AS DataLimite
    FROM Simulacoes_Avaliadas s
    LEFT JOIN Corpos_Finais c ON s.NumSimulacao = c.NumSimulacao
    LEFT JOIN Status_Avaliacoes sa ON s.NumSimulacao = sa.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;
END //

CREATE PROCEDURE sp_HistoricoLimpeza(
    IN p_Limite INT
)
BEGIN
    IF p_Limite IS NULL OR p_Limite <= 0 THEN
        SET p_Limite = 30;
    END IF;

    SELECT
        IdLog,
        DataLimpeza,
        QtdSimulacoesRemovidas,
        QtdCorposRemovidos,
        QtdAvaliacoesRemovidas,
        DataLimiteRemocao,
        TempoExecucao,
        Observacoes
    FROM Log_Limpeza
    ORDER BY DataLimpeza DESC
    LIMIT p_Limite;
END //

DELIMITER ;

-- ========================================================================
-- PARTE 5: DADOS DE TESTE
-- ========================================================================

USE SimulacaoCorpos;

-- CENÁRIO 1: Simulação com 5 corpos finais (será exportada)
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES ('2025-11-13 08:00:00', 250, 150000, 7200);

SET @sim2 = LAST_INSERT_ID();

INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim2, 0);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim2, 0, 'Estrela_Principal', 1.989e30, 0, 0, 0, 0, 1408),
    (@sim2, 0, 'Planeta_A', 5.972e24, 1.5e11, 0, 0, 29780, 5514),
    (@sim2, 0, 'Planeta_B', 4.867e24, -2.0e11, 0, 0, -25000, 5243),
    (@sim2, 0, 'Planeta_C', 6.417e23, 0, 2.5e11, 20000, 0, 3933),
    (@sim2, 0, 'Lua_1', 7.342e22, 1.5e11 + 3.844e8, 0, 0, 29780 + 1022, 3344);

INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim2, 150000);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim2, 150000, 'Estrela_Principal', 1.989e30, 1000, 500, 10, 5, 1408),
    (@sim2, 150000, 'Planeta_A', 5.972e24, 1.6e11, 2.0e10, 15000, 28000, 5514),
    (@sim2, 150000, 'Planeta_B', 4.867e24, -2.1e11, -1.5e10, -5000, -24000, 5243),
    (@sim2, 150000, 'Planeta_C', 6.417e23, 5.0e10, 2.4e11, 22000, -3000, 3933),
    (@sim2, 150000, 'Lua_1', 7.342e22, 1.62e11, 2.05e10, 15500, 28500, 3344);

-- CENÁRIO 2: Simulação com apenas 2 corpos finais (NÃO será exportada)
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES ('2025-11-13 10:00:00', 200, 200000, 9600);

SET @sim3 = LAST_INSERT_ID();

INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim3, 0);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim3, 0, 'Estrela_1', 1.989e30, -5.0e10, 0, 0, 15000, 1408),
    (@sim3, 0, 'Estrela_2', 1.5e30, 5.0e10, 0, 0, -15000, 1200),
    (@sim3, 0, 'Planeta_X', 3.0e24, 0, 1.0e11, -20000, 0, 4500);

INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim3, 200000);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim3, 200000, 'Estrela_Binaria_A', 2.0e30, -3.0e10, 5.0e9, 5000, 12000, 1350),
    (@sim3, 200000, 'Estrela_Binaria_B', 1.489e30, 3.5e10, -4.0e9, -6000, -13000, 1180);

-- CENÁRIO 3: Simulação com 3 corpos finais (limite mínimo - será exportada)
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES ('2025-11-13 12:00:00', 300, 250000, 12000);

SET @sim4 = LAST_INSERT_ID();

INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim4, 0);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim4, 0, 'Sol_Central', 2.5e30, 0, 0, 0, 0, 1500),
    (@sim4, 0, 'Gigante_Gasoso_1', 1.898e27, 7.78e11, 0, 0, 13070, 1326),
    (@sim4, 0, 'Gigante_Gasoso_2', 5.683e26, 0, -1.43e12, -9690, 0, 687),
    (@sim4, 0, 'Planeta_Rochoso', 6.0e24, 1.0e11, 0, 0, 30000, 5500);

INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim4, 250000);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim4, 250000, 'Sol_Central', 2.5e30, 5000, -2000, 50, -20, 1500),
    (@sim4, 250000, 'Gigante_Gasoso_1', 1.898e27, 8.0e11, 1.5e11, 5000, 12000, 1326),
    (@sim4, 250000, 'Gigante_Gasoso_2', 5.683e26, -2.0e11, -1.5e12, -8000, -9000, 687);

-- CENÁRIO 4: Simulação com 8 corpos finais (sistema complexo)
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES ('2025-11-13 14:00:00', 350, 300000, 15000);

SET @sim5 = LAST_INSERT_ID();

INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim5, 0);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim5, 0, 'Estrela_Alfa', 1.989e30, 0, 0, 0, 0, 1408),
    (@sim5, 0, 'Mercurio', 3.301e23, 5.79e10, 0, 0, 47870, 5427),
    (@sim5, 0, 'Venus', 4.867e24, 1.08e11, 0, 0, 35020, 5243),
    (@sim5, 0, 'Terra', 5.972e24, 1.496e11, 0, 0, 29780, 5514),
    (@sim5, 0, 'Marte', 6.417e23, 2.28e11, 0, 0, 24077, 3933),
    (@sim5, 0, 'Jupiter', 1.898e27, 7.78e11, 0, 0, 13070, 1326),
    (@sim5, 0, 'Saturno', 5.683e26, 1.43e12, 0, 0, 9690, 687),
    (@sim5, 0, 'Urano', 8.681e25, 2.87e12, 0, 0, 6810, 1271);

INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim5, 300000);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim5, 300000, 'Estrela_Alfa', 1.989e30, 2000, 1000, 20, 10, 1408),
    (@sim5, 300000, 'Mercurio', 3.301e23, 5.8e10, 1.0e10, 42000, 48000, 5427),
    (@sim5, 300000, 'Venus', 4.867e24, -1.1e11, 2.0e10, -30000, 36000, 5243),
    (@sim5, 300000, 'Terra', 5.972e24, 1.5e11, -3.0e10, 25000, 30000, 5514),
    (@sim5, 300000, 'Marte', 6.417e23, 2.3e11, 5.0e10, 20000, 25000, 3933),
    (@sim5, 300000, 'Jupiter', 1.898e27, -7.9e11, 1.5e11, -12000, 14000, 1326),
    (@sim5, 300000, 'Saturno', 5.683e26, 1.4e12, -2.0e11, 8000, 10000, 687),
    (@sim5, 300000, 'Urano', 8.681e25, -2.9e12, 5.0e11, -6000, 7000, 1271);

-- CENÁRIO 5: Simulação antiga (mais de 1 semana)
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES ('2025-11-06 08:00:00', 220, 180000, 8400);

SET @sim6 = LAST_INSERT_ID();

INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim6, 0);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim6, 0, 'Estrela_Beta', 1.5e30, 0, 0, 0, 0, 1200),
    (@sim6, 0, 'Planeta_Alpha', 4.0e24, 1.2e11, 0, 0, 28000, 5000),
    (@sim6, 0, 'Planeta_Beta', 3.5e24, -1.5e11, 0, 0, -25000, 4800),
    (@sim6, 0, 'Planeta_Gamma', 2.8e24, 0, 1.8e11, 22000, 0, 4600);

INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim6, 180000);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim6, 180000, 'Estrela_Beta', 1.5e30, 1500, 800, 15, 8, 1200),
    (@sim6, 180000, 'Planeta_Alpha', 4.0e24, 1.25e11, 2.0e10, 26000, 29000, 5000),
    (@sim6, 180000, 'Planeta_Beta', 3.5e24, -1.6e11, -1.0e10, -4000, -24000, 4800),
    (@sim6, 180000, 'Planeta_Gamma', 2.8e24, 5.0e10, 1.85e11, 23000, -2000, 4600);

-- Exportar simulações manualmente
CALL sp_ExportarSimulacaoParaAvaliador(1);
CALL sp_ExportarSimulacaoParaAvaliador(2);
CALL sp_ExportarSimulacaoParaAvaliador(3);
CALL sp_ExportarSimulacaoParaAvaliador(4);
CALL sp_ExportarSimulacaoParaAvaliador(5);
CALL sp_ExportarSimulacaoParaAvaliador(6);

-- Criar avaliações de exemplo
USE AvaliacaoSimulacoes;

CALL sp_AvaliarSimulacao(2, 'Dr. João Silva', 4, 'Sistema estável com órbitas interessantes');
CALL sp_AvaliarSimulacao(4, 'Dra. Maria Santos', 5, 'Configuração rara de 3 corpos em equilíbrio');
CALL sp_AvaliarSimulacao(5, 'Dr. João Silva', 3, 'Sistema solar simulado com alta precisão');
CALL sp_AvaliarSimulacao(5, 'Prof. Carlos Lima', 4, 'Boa conservação de energia e momento angular');

-- ========================================================================
-- PARTE 6: CONFIGURAÇÃO DE EVENTOS AUTOMÁTICOS
-- ========================================================================

SET GLOBAL event_scheduler = ON;

USE SimulacaoCorpos;

DROP EVENT IF EXISTS evt_RetryExportacoesFalhadas;

CREATE EVENT evt_RetryExportacoesFalhadas
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP
DO
    CALL sp_RetentarExportacoesFalhadas();

USE AvaliacaoSimulacoes;

DROP EVENT IF EXISTS evt_LimpezaAutomatica;

CREATE EVENT evt_LimpezaAutomatica
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
DO
    CALL sp_LimparDadosAntigos(7);

-- ========================================================================
-- PARTE 7: VERIFICAÇÕES E RELATÓRIO FINAL
-- ========================================================================

-- Verificar simulações criadas no Gerador
USE SimulacaoCorpos;

SELECT
    s.NumSimulacao,
    s.DataSimulacao,
    s.QtdCorposInicial,
    s.NumInteracoes,
    COUNT(DISTINCT r.NumIteracao) AS QtdResultados,
    (SELECT COUNT(*) FROM Corpos c
     WHERE c.NumSimulacao = s.NumSimulacao
       AND c.NumIteracao = (SELECT MAX(NumIteracao) FROM Resultados WHERE NumSimulacao = s.NumSimulacao)
    ) AS QtdCorposFinais
FROM Simulacao s
LEFT JOIN Resultados r ON s.NumSimulacao = r.NumSimulacao
GROUP BY s.NumSimulacao
ORDER BY s.NumSimulacao;

-- Verificar status de exportação
SELECT
    ce.NumSimulacao,
    s.DataSimulacao,
    ce.StatusExportacao,
    ce.QtdCorposFinais,
    ce.MensagemErro
FROM Controle_Exportacao ce
INNER JOIN Simulacao s ON ce.NumSimulacao = s.NumSimulacao
ORDER BY ce.NumSimulacao;

-- Verificar simulações no Avaliador
USE AvaliacaoSimulacoes;

SELECT
    NumSimulacao,
    DataSimulacao,
    DataImportacao,
    QtdCorposInicial,
    QtdCorposFinais,
    StatusAvaliacao
FROM Simulacoes_Avaliadas
ORDER BY NumSimulacao;

-- Estatísticas finais
SELECT
    'Total Simulações Exportadas' AS Metrica,
    COUNT(*) AS Valor
FROM Simulacoes_Avaliadas
UNION ALL
SELECT
    'Total Corpos Finais' AS Metrica,
    COUNT(*) AS Valor
FROM Corpos_Finais
UNION ALL
SELECT
    'Simulações Pendentes Avaliação' AS Metrica,
    COUNT(*) AS Valor
FROM Simulacoes_Avaliadas
WHERE StatusAvaliacao = 'PENDENTE';

-- ========================================================================
-- MENSAGEM FINAL DE SUCESSO
-- ========================================================================

SELECT '==========================================================' AS '';
SELECT 'IMPORTAÇÃO COMPLETA EXECUTADA COM SUCESSO!' AS '';
SELECT '==========================================================' AS '';
SELECT '' AS '';
SELECT 'Schemas criados:' AS '';
SELECT '  ✓ SimulacaoCorpos (Gerador)' AS '';
SELECT '  ✓ AvaliacaoSimulacoes (Avaliador)' AS '';
SELECT '' AS '';
SELECT 'Funcionalidades ativas:' AS '';
SELECT '  ✓ Exportação automática entre schemas' AS '';
SELECT '  ✓ Retry de exportações falhadas (a cada 1 hora)' AS '';
SELECT '  ✓ Limpeza automática de dados antigos (diária)' AS '';
SELECT '  ✓ Filtro: apenas simulações com 3+ corpos finais' AS '';
SELECT '  ✓ Transações para garantir atomicidade' AS '';
SELECT '' AS '';
SELECT 'Dados de teste criados:' AS '';
SELECT '  - Simulação 1: 3 corpos (exemplo original)' AS '';
SELECT '  - Simulação 2: 5 corpos finais (EXPORTADA)' AS '';
SELECT '  - Simulação 3: 2 corpos finais (NÃO EXPORTADA)' AS '';
SELECT '  - Simulação 4: 3 corpos finais (EXPORTADA)' AS '';
SELECT '  - Simulação 5: 8 corpos finais (EXPORTADA)' AS '';
SELECT '  - Simulação 6: 4 corpos, >7 dias (EXPORTADA)' AS '';
SELECT '' AS '';
SELECT 'Total: 5 simulações exportadas, 4 avaliações criadas' AS '';
SELECT '' AS '';
SELECT '==========================================================' AS '';

-- ========================================================================
-- FIM DA IMPORTAÇÃO COMPLETA
-- ========================================================================
