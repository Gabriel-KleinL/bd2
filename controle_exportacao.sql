-- ========================================================================
-- SISTEMA DE CONTROLE DE EXPORTAÇÃO - VERSÃO CORRIGIDA
-- ========================================================================

USE SimulacaoCorpos;

-- Criar tabela de controle de exportação
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

-- Criar índices
CREATE INDEX idx_controle_status ON Controle_Exportacao(StatusExportacao);
CREATE INDEX idx_controle_data ON Controle_Exportacao(DataUltimaTentativa);
CREATE INDEX idx_resultados_sim_iter ON Resultados(NumSimulacao, NumIteracao DESC);
CREATE INDEX idx_corpos_exportacao ON Corpos(NumSimulacao, NumIteracao);

-- ========================================================================
-- Stored Procedure de exportação (CORRIGIDA)
-- ========================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS sp_ExportarSimulacaoParaAvaliador //

CREATE PROCEDURE sp_ExportarSimulacaoParaAvaliador(
    IN p_NumSimulacao INT
)
proc_label: BEGIN  -- CORREÇÃO: Adicionar rótulo ao bloco BEGIN
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

    -- Verificar se a simulação existe
    SELECT COUNT(*) INTO @sim_existe
    FROM Simulacao
    WHERE NumSimulacao = p_NumSimulacao;

    IF @sim_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Simulação não encontrada';
    END IF;

    -- Buscar dados da simulação
    SELECT DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes
    INTO v_DataSimulacao, v_QtdCorposInicial, v_NumInteracoes, v_TempoInteracoes
    FROM Simulacao
    WHERE NumSimulacao = p_NumSimulacao;

    -- Buscar última iteração
    SELECT MAX(NumIteracao)
    INTO v_UltimaIteracao
    FROM Resultados
    WHERE NumSimulacao = p_NumSimulacao;

    -- Se não tem resultados, marcar como PENDENTE
    IF v_UltimaIteracao IS NULL THEN
        INSERT INTO Controle_Exportacao (NumSimulacao, StatusExportacao, QtdCorposFinais)
        VALUES (p_NumSimulacao, 'PENDENTE', 0)
        ON DUPLICATE KEY UPDATE
            StatusExportacao = 'PENDENTE',
            DataUltimaTentativa = NOW();
        SELECT CONCAT('Simulação ', p_NumSimulacao, ' ainda não possui resultados. Marcada como PENDENTE.') AS Resultado;
        LEAVE proc_label;  -- CORREÇÃO: Usar o rótulo correto
    END IF;

    -- Contar corpos finais
    SELECT COUNT(*)
    INTO v_QtdCorposFinais
    FROM Corpos
    WHERE NumSimulacao = p_NumSimulacao
      AND NumIteracao = v_UltimaIteracao;

    -- Se tem menos de 3 corpos, não exportar
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
        LEAVE proc_label;  -- CORREÇÃO: Usar o rótulo correto
    END IF;

    -- Verificar se já foi exportada com sucesso
    SELECT StatusExportacao, NumTentativas
    INTO v_StatusAtual, v_NumTentativas
    FROM Controle_Exportacao
    WHERE NumSimulacao = p_NumSimulacao;

    IF v_StatusAtual = 'SUCESSO' THEN
        SELECT CONCAT('Simulação ', p_NumSimulacao, ' já foi exportada com sucesso anteriormente.') AS Resultado;
        LEAVE proc_label;  -- CORREÇÃO: Usar o rótulo correto
    END IF;

    -- Iniciar transação para exportação
    START TRANSACTION;

    -- Inserir na tabela Simulacoes_Avaliadas
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

    -- Inserir resultados finais
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

    -- Inserir corpos finais com cálculos de energia e momento
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

    -- Registrar no histórico
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

    -- Atualizar controle de exportação
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

-- ========================================================================
-- Procedure para retentar exportações falhadas
-- ========================================================================

DROP PROCEDURE IF EXISTS sp_RetentarExportacoesFalhadas //

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

-- ========================================================================
-- Trigger para exportação automática
-- ========================================================================

DELIMITER //

DROP TRIGGER IF EXISTS trg_ExportarAntesNovaSimulacao //

CREATE TRIGGER trg_ExportarAntesNovaSimulacao
AFTER INSERT ON Simulacao
FOR EACH ROW
BEGIN
    DECLARE v_SimulacaoAnterior INT;
    DECLARE v_StatusExportacao VARCHAR(20);

    -- Buscar simulação anterior
    SELECT MAX(NumSimulacao) INTO v_SimulacaoAnterior
    FROM Simulacao
    WHERE NumSimulacao < NEW.NumSimulacao;

    -- Se existe simulação anterior, verificar se foi exportada
    IF v_SimulacaoAnterior IS NOT NULL THEN
        SELECT StatusExportacao INTO v_StatusExportacao
        FROM Controle_Exportacao
        WHERE NumSimulacao = v_SimulacaoAnterior;

        -- Se não foi exportada ou falhou, tentar exportar
        IF v_StatusExportacao IS NULL OR v_StatusExportacao != 'SUCESSO' THEN
            CALL sp_ExportarSimulacaoParaAvaliador(v_SimulacaoAnterior);
        END IF;
    END IF;

    -- Inserir registro de controle para a nova simulação
    INSERT INTO Controle_Exportacao (NumSimulacao, StatusExportacao)
    VALUES (NEW.NumSimulacao, 'PENDENTE');
END //

DELIMITER ;

-- ========================================================================
-- ROTINAS DE LIMPEZA AUTOMÁTICA
-- ========================================================================

USE AvaliacaoSimulacoes;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_LimparDadosAntigos //

CREATE PROCEDURE sp_LimparDadosAntigos(
    IN p_DiasRetencao INT
)
proc_label: BEGIN  -- CORREÇÃO: Adicionar rótulo ao bloco BEGIN
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

    -- Contar quantos registros serão removidos
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
        LEAVE proc_label;  -- CORREÇÃO: Usar o rótulo correto
    END IF;

    -- Iniciar transação para remoção
    START TRANSACTION;

    -- Remover em ordem: dependências primeiro
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

    -- Calcular tempo de execução
    SET v_TempoExecucao = TIMESTAMPDIFF(SECOND, v_InicioExecucao, CURRENT_TIMESTAMP);

    -- Registrar no log
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

    -- Otimizar tabelas
    OPTIMIZE TABLE Simulacoes_Avaliadas;
    OPTIMIZE TABLE Resultados_Finais;
    OPTIMIZE TABLE Corpos_Finais;
    OPTIMIZE TABLE Status_Avaliacoes;
    OPTIMIZE TABLE Historico_Exportacoes;

    -- Retornar resumo
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
-- Procedure para preview da limpeza
-- ========================================================================

DROP PROCEDURE IF EXISTS sp_PreviewLimpeza //

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

    -- Mostrar totais
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
-- Procedure para ver histórico de limpezas
-- ========================================================================

DROP PROCEDURE IF EXISTS sp_HistoricoLimpeza //

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
-- CONFIGURAÇÃO DE EVENTOS AUTOMÁTICOS
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
-- MENSAGEM FINAL
-- ========================================================================

SELECT '==========================================================' AS '';
SELECT 'CONTROLE DE EXPORTAÇÃO CRIADO COM SUCESSO!' AS '';
SELECT '==========================================================' AS '';
SELECT '' AS '';
SELECT 'Componentes criados:' AS '';
SELECT '  ✓ Tabela Controle_Exportacao' AS '';
SELECT '  ✓ Procedure sp_ExportarSimulacaoParaAvaliador' AS '';
SELECT '  ✓ Procedure sp_RetentarExportacoesFalhadas' AS '';
SELECT '  ✓ Trigger trg_ExportarAntesNovaSimulacao' AS '';
SELECT '  ✓ Procedure sp_LimparDadosAntigos' AS '';
SELECT '  ✓ Procedure sp_PreviewLimpeza' AS '';
SELECT '  ✓ Procedure sp_HistoricoLimpeza' AS '';
SELECT '  ✓ Event evt_RetryExportacoesFalhadas (a cada 1 hora)' AS '';
SELECT '  ✓ Event evt_LimpezaAutomatica (diária)' AS '';
SELECT '' AS '';
SELECT 'Sistema pronto para uso!' AS '';
SELECT '==========================================================' AS '';
