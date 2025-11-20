-- ========================================================================
-- ROTINA DE LIMPEZA AUTOMÁTICA DE DADOS ANTIGOS
-- ========================================================================
-- Este script implementa a limpeza automática de simulações com mais de
-- 1 semana (7 dias) no banco do Avaliador
--
-- IMPORTANTE: Esta rotina remove apenas dados do AvaliacaoSimulacoes.
-- Os dados originais no SimulacaoCorpos são mantidos.
-- ========================================================================

USE AvaliacaoSimulacoes;

-- ========================================================================
-- 1. TABELA DE LOG DE LIMPEZA
-- ========================================================================

-- Criar tabela para registrar histórico de limpezas
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
-- 2. STORED PROCEDURE DE LIMPEZA
-- ========================================================================

DELIMITER //

-- Procedure principal de limpeza
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

    -- Registrar início da execução
    SET v_InicioExecucao = CURRENT_TIMESTAMP;

    -- Calcular data limite (simulações anteriores a esta data serão removidas)
    SET v_DataLimite = DATE_SUB(NOW(), INTERVAL p_DiasRetencao DAY);

    -- Contar quantos registros serão removidos (para log)
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

    -- Se não há nada para remover, sair
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

    -- Iniciar transação para garantir atomicidade
    START TRANSACTION;

    -- Remover dados em cascata (as FKs com CASCADE cuidam das tabelas dependentes)
    -- A ordem é importante devido às dependências

    -- 1. Remover avaliações (opcional, seria removido em cascata)
    DELETE sa FROM Status_Avaliacoes sa
    INNER JOIN Simulacoes_Avaliadas s ON sa.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    -- 2. Remover histórico de exportações (opcional, seria removido em cascata)
    DELETE h FROM Historico_Exportacoes h
    INNER JOIN Simulacoes_Avaliadas s ON h.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    -- 3. Remover corpos finais (opcional, seria removido em cascata)
    DELETE c FROM Corpos_Finais c
    INNER JOIN Simulacoes_Avaliadas s ON c.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    -- 4. Remover resultados finais (opcional, seria removido em cascata)
    DELETE r FROM Resultados_Finais r
    INNER JOIN Simulacoes_Avaliadas s ON r.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    -- 5. Remover simulações (tabela principal)
    DELETE FROM Simulacoes_Avaliadas
    WHERE DataImportacao < v_DataLimite;

    -- Commit da transação
    COMMIT;

    -- Calcular tempo de execução
    SET v_TempoExecucao = TIMESTAMPDIFF(SECOND, v_InicioExecucao, CURRENT_TIMESTAMP);

    -- Registrar log de limpeza
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

    -- Otimizar tabelas após limpeza (liberar espaço)
    OPTIMIZE TABLE Simulacoes_Avaliadas;
    OPTIMIZE TABLE Resultados_Finais;
    OPTIMIZE TABLE Corpos_Finais;
    OPTIMIZE TABLE Status_Avaliacoes;
    OPTIMIZE TABLE Historico_Exportacoes;

    -- Retornar resultado
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

-- ========================================================================
-- 3. PROCEDURE DE LIMPEZA COM PREVIEW
-- ========================================================================

-- Procedure para visualizar o que será removido sem remover
CREATE PROCEDURE sp_PreviewLimpeza(
    IN p_DiasRetencao INT
)
BEGIN
    DECLARE v_DataLimite DATETIME;

    SET v_DataLimite = DATE_SUB(NOW(), INTERVAL p_DiasRetencao DAY);

    -- Mostrar simulações que seriam removidas
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

    -- Mostrar estatísticas gerais
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

-- ========================================================================
-- 4. PROCEDURE PARA VISUALIZAR HISTÓRICO DE LIMPEZAS
-- ========================================================================

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
-- 5. EVENT SCHEDULER PARA LIMPEZA AUTOMÁTICA
-- ========================================================================

-- Garantir que o Event Scheduler está ativado
SET GLOBAL event_scheduler = ON;

-- Evento que executa limpeza automática todos os dias à meia-noite
DROP EVENT IF EXISTS evt_LimpezaAutomatica;

CREATE EVENT evt_LimpezaAutomatica
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)  -- Próxima meia-noite
DO
    CALL sp_LimparDadosAntigos(7);  -- Remover dados com mais de 7 dias

-- ========================================================================
-- 6. CONSULTAS ÚTEIS PARA MONITORAMENTO
-- ========================================================================

-- Ver estatísticas de dados armazenados
/*
SELECT
    'Total Simulações' AS Metrica,
    COUNT(*) AS Valor
FROM Simulacoes_Avaliadas
UNION ALL
SELECT
    'Simulações Antigas (>7 dias)' AS Metrica,
    COUNT(*) AS Valor
FROM Simulacoes_Avaliadas
WHERE DataImportacao < DATE_SUB(NOW(), INTERVAL 7 DAY)
UNION ALL
SELECT
    'Total Corpos' AS Metrica,
    COUNT(*) AS Valor
FROM Corpos_Finais
UNION ALL
SELECT
    'Total Avaliações' AS Metrica,
    COUNT(*) AS Valor
FROM Status_Avaliacoes;
*/

-- Ver tamanho das tabelas
/*
SELECT
    table_name AS Tabela,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS TamanhoMB,
    table_rows AS LinhasAproximadas
FROM information_schema.TABLES
WHERE table_schema = 'AvaliacaoSimulacoes'
ORDER BY (data_length + index_length) DESC;
*/

-- Ver simulações mais antigas
/*
SELECT
    NumSimulacao,
    DataSimulacao,
    DataImportacao,
    DATEDIFF(NOW(), DataImportacao) AS DiasDesdeImportacao,
    QtdCorposFinais,
    StatusAvaliacao
FROM Simulacoes_Avaliadas
ORDER BY DataImportacao ASC
LIMIT 10;
*/

-- ========================================================================
-- 7. TESTES E EXEMPLOS
-- ========================================================================

-- Exemplo 1: Preview da limpeza (ver o que seria removido)
-- CALL sp_PreviewLimpeza(7);

-- Exemplo 2: Executar limpeza manualmente
-- CALL sp_LimparDadosAntigos(7);

-- Exemplo 3: Ver histórico de limpezas
-- CALL sp_HistoricoLimpeza(10);

-- Exemplo 4: Ver último log de limpeza
-- SELECT * FROM Log_Limpeza ORDER BY DataLimpeza DESC LIMIT 1;

-- ========================================================================
-- FIM DA ROTINA DE LIMPEZA
-- ========================================================================
