-- ========================================================================
-- INTEGRAÇÃO ENTRE GERADOR E AVALIADOR DE SIMULAÇÕES
-- ========================================================================
-- Este script implementa a exportação automática de simulações do
-- schema SimulacaoCorpos (Gerador) para AvaliacaoSimulacoes (Avaliador)
--
-- FUNCIONALIDADES:
-- 1. Exportação automática ao iniciar nova simulação
-- 2. Garantia de atomicidade (tudo ou nada)
-- 3. Retry automático em caso de falha
-- 4. Filtro: apenas simulações com 3+ corpos finais
-- 5. Controle de exportações
-- ========================================================================

USE SimulacaoCorpos;

-- ========================================================================
-- 1. TABELA DE CONTROLE DE EXPORTAÇÃO (NO GERADOR)
-- ========================================================================

-- Tabela para controlar quais simulações já foram exportadas
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

-- Índices para otimização
CREATE INDEX idx_controle_status ON Controle_Exportacao(StatusExportacao);
CREATE INDEX idx_controle_data ON Controle_Exportacao(DataUltimaTentativa);

-- ========================================================================
-- 2. ÍNDICES ADICIONAIS PARA OTIMIZAR EXPORTAÇÃO
-- ========================================================================

-- Índice composto para buscar rapidamente a última iteração de uma simulação
CREATE INDEX idx_resultados_sim_iter ON Resultados(NumSimulacao, NumIteracao DESC);

-- Índice para buscar corpos de uma simulação/iteração específica
CREATE INDEX idx_corpos_exportacao ON Corpos(NumSimulacao, NumIteracao);

-- ========================================================================
-- 3. STORED PROCEDURE DE EXPORTAÇÃO
-- ========================================================================

DELIMITER //

-- Procedure principal de exportação com controle transacional
CREATE PROCEDURE sp_ExportarSimulacaoParaAvaliador(
    IN p_NumSimulacao INT
)
proc_label: BEGIN
    -- Declaração de variáveis
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

    -- Handler para capturar erros
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Em caso de erro, fazer rollback e registrar falha
        ROLLBACK;

        -- Atualizar controle de exportação
        UPDATE Controle_Exportacao
        SET StatusExportacao = 'FALHA',
            DataUltimaTentativa = NOW(),
            NumTentativas = NumTentativas + 1,
            MensagemErro = v_ErroMsg
        WHERE NumSimulacao = p_NumSimulacao;

        -- Registrar no histórico do avaliador (se a conexão estiver disponível)
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

    -- Obter dados da simulação
    SELECT DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes
    INTO v_DataSimulacao, v_QtdCorposInicial, v_NumInteracoes, v_TempoInteracoes
    FROM Simulacao
    WHERE NumSimulacao = p_NumSimulacao;

    -- Verificar se há resultados
    SELECT MAX(NumIteracao)
    INTO v_UltimaIteracao
    FROM Resultados
    WHERE NumSimulacao = p_NumSimulacao;

    IF v_UltimaIteracao IS NULL THEN
        -- Simulação ainda não tem resultados, marcar como pendente
        INSERT INTO Controle_Exportacao (NumSimulacao, StatusExportacao, QtdCorposFinais)
        VALUES (p_NumSimulacao, 'PENDENTE', 0)
        ON DUPLICATE KEY UPDATE
            StatusExportacao = 'PENDENTE',
            DataUltimaTentativa = NOW();

        SELECT CONCAT('Simulação ', p_NumSimulacao, ' ainda não possui resultados. Marcada como PENDENTE.') AS Resultado;
        LEAVE proc_label;
    END IF;

    -- Contar quantos corpos restaram na última iteração
    SELECT COUNT(*)
    INTO v_QtdCorposFinais
    FROM Corpos
    WHERE NumSimulacao = p_NumSimulacao
      AND NumIteracao = v_UltimaIteracao;

    -- Verificar se a simulação atende ao critério mínimo (3+ corpos)
    IF v_QtdCorposFinais < 3 THEN
        -- Atualizar controle indicando que não será exportada
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

    -- Verificar status atual da exportação
    SELECT StatusExportacao, NumTentativas
    INTO v_StatusAtual, v_NumTentativas
    FROM Controle_Exportacao
    WHERE NumSimulacao = p_NumSimulacao;

    -- Se já foi exportada com sucesso, não exportar novamente
    IF v_StatusAtual = 'SUCESSO' THEN
        SELECT CONCAT('Simulação ', p_NumSimulacao, ' já foi exportada com sucesso anteriormente.') AS Resultado;
        LEAVE proc_label;
    END IF;

    -- Iniciar transação para garantir atomicidade
    START TRANSACTION;

    -- EXPORTAÇÃO: Inserir dados no schema AvaliacaoSimulacoes

    -- 1. Inserir na tabela Simulacoes_Avaliadas
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

    -- 2. Inserir na tabela Resultados_Finais
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

    -- 3. Inserir na tabela Corpos_Finais (apenas corpos da última iteração)
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
        -- Calcular energia cinética: 0.5 * m * v²
        0.5 * c.MassaCorpo * (POWER(c.VelX, 2) + POWER(c.VelY, 2)) AS EnergiaTotal,
        -- Calcular momento angular: L = r × p = m * (x*vy - y*vx)
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

    -- 4. Registrar no histórico de exportações
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

    -- Commit da transação
    COMMIT;

    -- Atualizar controle de exportação como SUCESSO
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
-- 4. PROCEDURE DE RETRY PARA SIMULAÇÕES FALHADAS
-- ========================================================================

-- Procedure para tentar reexportar simulações que falharam
CREATE PROCEDURE sp_RetentarExportacoesFalhadas()
BEGIN
    DECLARE v_NumSimulacao INT;
    DECLARE v_Finalizado INT DEFAULT 0;

    -- Cursor para percorrer simulações com falha
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

        -- Tentar exportar novamente
        CALL sp_ExportarSimulacaoParaAvaliador(v_NumSimulacao);

    END LOOP;

    CLOSE cursor_falhas;

    SELECT 'Retry de exportações falhadas concluído' AS Resultado;
END //

-- ========================================================================
-- 5. TRIGGER PARA EXECUÇÃO AUTOMÁTICA
-- ========================================================================

-- Trigger que executa a exportação ao iniciar uma nova simulação
-- (detecta inserção de um novo registro na tabela Simulacao)
DROP TRIGGER IF EXISTS trg_ExportarAntesNovaSimulacao //

CREATE TRIGGER trg_ExportarAntesNovaSimulacao
AFTER INSERT ON Simulacao
FOR EACH ROW
BEGIN
    DECLARE v_SimulacaoAnterior INT;
    DECLARE v_StatusExportacao VARCHAR(20);

    -- Obter o número da simulação anterior (a última antes da que acabou de ser inserida)
    SELECT MAX(NumSimulacao) INTO v_SimulacaoAnterior
    FROM Simulacao
    WHERE NumSimulacao < NEW.NumSimulacao;

    -- Se existe uma simulação anterior, tentar exportá-la
    IF v_SimulacaoAnterior IS NOT NULL THEN

        -- Verificar o status atual da exportação
        SELECT StatusExportacao INTO v_StatusExportacao
        FROM Controle_Exportacao
        WHERE NumSimulacao = v_SimulacaoAnterior;

        -- Exportar se ainda não foi exportada com sucesso ou se está pendente/falhada
        IF v_StatusExportacao IS NULL OR v_StatusExportacao != 'SUCESSO' THEN
            CALL sp_ExportarSimulacaoParaAvaliador(v_SimulacaoAnterior);
        END IF;

    END IF;

    -- Inserir controle para a nova simulação (status PENDENTE)
    INSERT INTO Controle_Exportacao (NumSimulacao, StatusExportacao)
    VALUES (NEW.NumSimulacao, 'PENDENTE');

END //

DELIMITER ;

-- ========================================================================
-- 6. EVENT PARA RETRY PERIÓDICO
-- ========================================================================

-- Ativar o Event Scheduler (necessário para eventos automáticos)
SET GLOBAL event_scheduler = ON;

-- Evento que executa retry de exportações falhadas a cada 1 hora
DROP EVENT IF EXISTS evt_RetryExportacoesFalhadas;

CREATE EVENT evt_RetryExportacoesFalhadas
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP
DO
    CALL sp_RetentarExportacoesFalhadas();

-- ========================================================================
-- 7. CONSULTAS ÚTEIS PARA MONITORAMENTO
-- ========================================================================

-- Ver status de todas as exportações
/*
SELECT
    ce.NumSimulacao,
    s.DataSimulacao,
    ce.StatusExportacao,
    ce.NumTentativas,
    ce.QtdCorposFinais,
    ce.DataUltimaTentativa,
    ce.MensagemErro
FROM Controle_Exportacao ce
INNER JOIN Simulacao s ON ce.NumSimulacao = s.NumSimulacao
ORDER BY ce.NumSimulacao DESC;
*/

-- Ver simulações pendentes de exportação
/*
SELECT
    ce.NumSimulacao,
    s.DataSimulacao,
    s.QtdCorposInicial,
    ce.StatusExportacao,
    ce.NumTentativas
FROM Controle_Exportacao ce
INNER JOIN Simulacao s ON ce.NumSimulacao = s.NumSimulacao
WHERE ce.StatusExportacao = 'PENDENTE'
ORDER BY s.DataSimulacao ASC;
*/

-- Ver simulações que falharam na exportação
/*
SELECT
    ce.NumSimulacao,
    s.DataSimulacao,
    ce.NumTentativas,
    ce.MensagemErro,
    ce.DataUltimaTentativa
FROM Controle_Exportacao ce
INNER JOIN Simulacao s ON ce.NumSimulacao = s.NumSimulacao
WHERE ce.StatusExportacao = 'FALHA'
ORDER BY ce.DataUltimaTentativa DESC;
*/

-- ========================================================================
-- FIM DA INTEGRAÇÃO
-- ========================================================================
