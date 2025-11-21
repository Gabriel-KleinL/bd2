# Documentação: Triggers, Procedures e Limpeza do Banco

## Índice
1. [Triggers](#triggers)
2. [Stored Procedures](#stored-procedures)
3. [Sistema de Limpeza Automática](#sistema-de-limpeza-automática)
4. [Events Agendados](#events-agendados)

---

## Triggers

### 1. `trg_ExportarAntesNovaSimulacao`

**Localização:** `SimulacaoCorpos`
**Tabela:** `Simulacao`
**Evento:** `AFTER INSERT`

#### Como Funciona
Este trigger é ativado automaticamente **após a inserção** de uma nova simulação na tabela `Simulacao`. Ele garante que a simulação anterior seja exportada para o banco `AvaliacaoSimulacoes` antes de iniciar uma nova.

#### Por Que Existe
- **Garantir exportação automática:** Evita que simulações completas sejam esquecidas e não exportadas
- **Fluxo contínuo:** Mantém o sistema de avaliação sempre atualizado com as simulações concluídas
- **Prevenção de perda de dados:** Assegura que simulações finalizadas sejam transferidas antes de começar uma nova

#### Código SQL

```sql
DELIMITER //

DROP TRIGGER IF EXISTS trg_ExportarAntesNovaSimulacao //

CREATE TRIGGER trg_ExportarAntesNovaSimulacao
AFTER INSERT ON Simulacao
FOR EACH ROW
BEGIN
    DECLARE v_SimulacaoAnterior INT;
    DECLARE v_StatusExportacao VARCHAR(20);

    -- Buscar a simulação anterior (maior número menor que a nova)
    SELECT MAX(NumSimulacao) INTO v_SimulacaoAnterior
    FROM Simulacao
    WHERE NumSimulacao < NEW.NumSimulacao;

    -- Se existe simulação anterior
    IF v_SimulacaoAnterior IS NOT NULL THEN
        -- Verificar se foi exportada
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
```

#### Fluxo de Execução
1. Nova simulação é inserida (ID = 5)
2. Trigger busca a simulação anterior (ID = 4)
3. Verifica se a simulação 4 foi exportada
4. Se não foi exportada com sucesso, chama `sp_ExportarSimulacaoParaAvaliador(4)`
5. Cria registro de controle para a nova simulação (ID = 5) com status 'PENDENTE'

---

## Stored Procedures

### 1. `sp_ExportarSimulacaoParaAvaliador`

**Localização:** `SimulacaoCorpos`
**Parâmetro:** `p_NumSimulacao INT`

#### Como Funciona
Esta procedure exporta uma simulação completa do banco `SimulacaoCorpos` (Gerador) para o banco `AvaliacaoSimulacoes` (Avaliador). Ela verifica se a simulação tem pelo menos 3 corpos finais antes de exportar.

#### Por Que Existe
- **Integração entre schemas:** Transfere dados do gerador para o avaliador
- **Filtro de qualidade:** Exporta apenas simulações com 3+ corpos finais (critério científico)
- **Cálculos automáticos:** Calcula energia total e momento angular dos corpos
- **Atomicidade:** Usa transações para garantir consistência dos dados

#### Código SQL

```sql
DELIMITER //

DROP PROCEDURE IF EXISTS sp_ExportarSimulacaoParaAvaliador //

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
    DECLARE v_StatusAtual VARCHAR(20);
    DECLARE v_NumTentativas INT DEFAULT 0;

    -- Handler para erros
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        UPDATE Controle_Exportacao
        SET StatusExportacao = 'FALHA',
            DataUltimaTentativa = NOW(),
            NumTentativas = NumTentativas + 1,
            MensagemErro = v_ErroMsg
        WHERE NumSimulacao = p_NumSimulacao;
        SELECT CONCAT('Erro ao exportar simulação ', p_NumSimulacao) AS Resultado;
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
        SELECT CONCAT('Simulação ', p_NumSimulacao, ' ainda não possui resultados.') AS Resultado;
        LEAVE proc_label;
    END IF;

    -- Contar corpos finais
    SELECT COUNT(*)
    INTO v_QtdCorposFinais
    FROM Corpos
    WHERE NumSimulacao = p_NumSimulacao
      AND NumIteracao = v_UltimaIteracao;

    -- Filtro: precisa ter pelo menos 3 corpos finais
    IF v_QtdCorposFinais < 3 THEN
        INSERT INTO Controle_Exportacao (
            NumSimulacao, StatusExportacao, DataUltimaTentativa,
            QtdCorposFinais, MensagemErro
        )
        VALUES (
            p_NumSimulacao, 'SUCESSO', NOW(), v_QtdCorposFinais,
            'Simulação não exportada: menos de 3 corpos finais'
        )
        ON DUPLICATE KEY UPDATE
            StatusExportacao = 'SUCESSO',
            DataUltimaTentativa = NOW(),
            QtdCorposFinais = v_QtdCorposFinais,
            MensagemErro = 'Simulação não exportada: menos de 3 corpos finais';
        SELECT CONCAT('Simulação ', p_NumSimulacao, ' não exportada: apenas ',
                      v_QtdCorposFinais, ' corpos finais (mínimo: 3)') AS Resultado;
        LEAVE proc_label;
    END IF;

    -- Verificar se já foi exportada
    SELECT StatusExportacao, NumTentativas
    INTO v_StatusAtual, v_NumTentativas
    FROM Controle_Exportacao
    WHERE NumSimulacao = p_NumSimulacao;

    IF v_StatusAtual = 'SUCESSO' THEN
        SELECT CONCAT('Simulação ', p_NumSimulacao,
                      ' já foi exportada anteriormente.') AS Resultado;
        LEAVE proc_label;
    END IF;

    -- Iniciar transação
    START TRANSACTION;

    -- 1. Inserir simulação avaliada
    INSERT INTO AvaliacaoSimulacoes.Simulacoes_Avaliadas (
        NumSimulacao, DataSimulacao, DataImportacao,
        QtdCorposInicial, QtdCorposFinais, NumInteracoes,
        TempoInteracoes, StatusAvaliacao
    )
    VALUES (
        p_NumSimulacao, v_DataSimulacao, NOW(),
        v_QtdCorposInicial, v_QtdCorposFinais, v_NumInteracoes,
        v_TempoInteracoes, 'PENDENTE'
    )
    ON DUPLICATE KEY UPDATE
        DataImportacao = NOW(),
        QtdCorposFinais = v_QtdCorposFinais;

    -- 2. Inserir resultados finais
    INSERT INTO AvaliacaoSimulacoes.Resultados_Finais (
        NumSimulacao, NumIteracao, TempoExecucao
    )
    VALUES (p_NumSimulacao, v_UltimaIteracao, v_TempoInteracoes)
    ON DUPLICATE KEY UPDATE
        NumIteracao = v_UltimaIteracao,
        TempoExecucao = v_TempoInteracoes;

    -- 3. Inserir corpos finais com cálculos
    INSERT INTO AvaliacaoSimulacoes.Corpos_Finais (
        NumSimulacao, NomeCorpo, MassaCorpo,
        PosX, PosY, VelX, VelY, DensidadeCorpo,
        EnergiaTotal, MomentoAngular
    )
    SELECT
        c.NumSimulacao,
        c.NomeCorpo,
        c.MassaCorpo,
        c.PosX, c.PosY,
        c.VelX, c.VelY,
        c.DensidadeCorpo,
        -- Cálculo de Energia Cinética: E = 0.5 * m * v²
        0.5 * c.MassaCorpo * (POWER(c.VelX, 2) + POWER(c.VelY, 2)) AS EnergiaTotal,
        -- Cálculo de Momento Angular: L = m * (r × v)
        c.MassaCorpo * (c.PosX * c.VelY - c.PosY * c.VelX) AS MomentoAngular
    FROM Corpos c
    WHERE c.NumSimulacao = p_NumSimulacao
      AND c.NumIteracao = v_UltimaIteracao
    ON DUPLICATE KEY UPDATE
        NomeCorpo = VALUES(NomeCorpo),
        MassaCorpo = VALUES(MassaCorpo),
        PosX = VALUES(PosX), PosY = VALUES(PosY),
        VelX = VALUES(VelX), VelY = VALUES(VelY),
        DensidadeCorpo = VALUES(DensidadeCorpo),
        EnergiaTotal = VALUES(EnergiaTotal),
        MomentoAngular = VALUES(MomentoAngular);

    -- 4. Registrar no histórico
    INSERT INTO AvaliacaoSimulacoes.Historico_Exportacoes (
        NumSimulacao, DataTentativa, StatusExportacao, QtdCorposExportados
    )
    VALUES (p_NumSimulacao, NOW(), 'SUCESSO', v_QtdCorposFinais);

    COMMIT;

    -- Atualizar controle de exportação
    INSERT INTO Controle_Exportacao (
        NumSimulacao, StatusExportacao, DataUltimaTentativa,
        NumTentativas, QtdCorposFinais
    )
    VALUES (
        p_NumSimulacao, 'SUCESSO', NOW(),
        v_NumTentativas + 1, v_QtdCorposFinais
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

DELIMITER ;
```

#### Exemplo de Uso
```sql
-- Exportar simulação específica
CALL sp_ExportarSimulacaoParaAvaliador(5);

-- Resultado esperado:
-- "Simulação 5 exportada com sucesso! 8 corpos exportados."
```

---

### 2. `sp_RetentarExportacoesFalhadas`

**Localização:** `SimulacaoCorpos`
**Parâmetros:** Nenhum

#### Como Funciona
Esta procedure busca todas as simulações com status de exportação 'FALHA' e tenta exportá-las novamente. Usa um cursor para iterar sobre cada simulação falhada.

#### Por Que Existe
- **Recuperação automática:** Reprocessa exportações que falharam por erros temporários
- **Resiliência:** Garante que nenhuma simulação seja perdida por falhas pontuais
- **Manutenção automatizada:** Executada periodicamente por um Event

#### Código SQL

```sql
DELIMITER //

DROP PROCEDURE IF EXISTS sp_RetentarExportacoesFalhadas //

CREATE PROCEDURE sp_RetentarExportacoesFalhadas()
BEGIN
    DECLARE v_NumSimulacao INT;
    DECLARE v_Finalizado INT DEFAULT 0;

    -- Cursor para buscar todas as simulações falhadas
    DECLARE cursor_falhas CURSOR FOR
        SELECT NumSimulacao
        FROM Controle_Exportacao
        WHERE StatusExportacao = 'FALHA'
        ORDER BY DataUltimaTentativa ASC;  -- Mais antigas primeiro

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

DELIMITER ;
```

#### Exemplo de Uso
```sql
-- Executar manualmente
CALL sp_RetentarExportacoesFalhadas();

-- Verificar resultados
SELECT NumSimulacao, StatusExportacao, NumTentativas, MensagemErro
FROM Controle_Exportacao
WHERE StatusExportacao = 'FALHA';
```

---

### 3. `sp_LimparDadosAntigos`

**Localização:** `AvaliacaoSimulacoes`
**Parâmetro:** `p_DiasRetencao INT` (número de dias para reter os dados)

#### Como Funciona
Remove simulações e todos os dados relacionados (corpos, avaliações, histórico) que foram importados há mais de X dias. Opera de forma transacional para garantir consistência.

#### Por Que Existe
- **Gerenciamento de espaço:** Libera espaço em disco removendo dados antigos
- **Performance:** Mantém o banco otimizado removendo registros obsoletos
- **Política de retenção:** Implementa regra de negócio de guardar dados por tempo limitado
- **Auditoria:** Registra todas as limpezas em log para rastreabilidade

#### Código SQL

```sql
DELIMITER //

DROP PROCEDURE IF EXISTS sp_LimparDadosAntigos //

CREATE PROCEDURE sp_LimparDadosAntigos(
    IN p_DiasRetencao INT
)
proc_label: BEGIN
    -- Declaração de variáveis
    DECLARE v_DataLimite DATETIME;
    DECLARE v_QtdSimulacoes INT DEFAULT 0;
    DECLARE v_QtdCorpos INT DEFAULT 0;
    DECLARE v_QtdAvaliacoes INT DEFAULT 0;
    DECLARE v_QtdResultados INT DEFAULT 0;
    DECLARE v_QtdHistorico INT DEFAULT 0;
    DECLARE v_InicioExecucao TIMESTAMP;
    DECLARE v_TempoExecucao INT;

    -- Registrar início
    SET v_InicioExecucao = CURRENT_TIMESTAMP;

    -- Calcular data limite (remover dados anteriores a esta data)
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
            DataLimpeza, QtdSimulacoesRemovidas, DataLimiteRemocao,
            TempoExecucao, Observacoes
        )
        VALUES (
            NOW(), 0, v_DataLimite, 0,
            'Nenhuma simulação antiga encontrada para remoção'
        );
        SELECT 'Nenhuma simulação antiga encontrada.' AS Resultado;
        LEAVE proc_label;
    END IF;

    -- Iniciar transação
    START TRANSACTION;

    -- Remover em ordem: dependências primeiro, tabela principal por último

    -- 1. Remover avaliações
    DELETE sa FROM Status_Avaliacoes sa
    INNER JOIN Simulacoes_Avaliadas s ON sa.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    -- 2. Remover histórico de exportações
    DELETE h FROM Historico_Exportacoes h
    INNER JOIN Simulacoes_Avaliadas s ON h.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    -- 3. Remover corpos finais
    DELETE c FROM Corpos_Finais c
    INNER JOIN Simulacoes_Avaliadas s ON c.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    -- 4. Remover resultados finais
    DELETE r FROM Resultados_Finais r
    INNER JOIN Simulacoes_Avaliadas s ON r.NumSimulacao = s.NumSimulacao
    WHERE s.DataImportacao < v_DataLimite;

    -- 5. Remover simulações (tabela principal)
    DELETE FROM Simulacoes_Avaliadas
    WHERE DataImportacao < v_DataLimite;

    COMMIT;

    -- Calcular tempo de execução
    SET v_TempoExecucao = TIMESTAMPDIFF(SECOND, v_InicioExecucao, CURRENT_TIMESTAMP);

    -- Registrar no log
    INSERT INTO Log_Limpeza (
        DataLimpeza, QtdSimulacoesRemovidas, QtdCorposRemovidos,
        QtdAvaliacoesRemovidas, DataLimiteRemocao, TempoExecucao, Observacoes
    )
    VALUES (
        NOW(), v_QtdSimulacoes, v_QtdCorpos, v_QtdAvaliacoes,
        v_DataLimite, v_TempoExecucao,
        CONCAT('Limpeza executada com sucesso. Removidos: ',
               v_QtdSimulacoes, ' simulações, ',
               v_QtdResultados, ' resultados, ',
               v_QtdCorpos, ' corpos, ',
               v_QtdAvaliacoes, ' avaliações, ',
               v_QtdHistorico, ' históricos')
    );

    -- Otimizar tabelas (liberar espaço em disco)
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

DELIMITER ;
```

#### Exemplo de Uso
```sql
-- Remover dados com mais de 7 dias
CALL sp_LimparDadosAntigos(7);

-- Remover dados com mais de 30 dias
CALL sp_LimparDadosAntigos(30);

-- Verificar log de limpeza
SELECT * FROM Log_Limpeza ORDER BY DataLimpeza DESC LIMIT 5;
```

---

### 4. `sp_PreviewLimpeza`

**Localização:** `AvaliacaoSimulacoes`
**Parâmetro:** `p_DiasRetencao INT`

#### Como Funciona
Mostra quais simulações seriam removidas **sem efetivamente remover**. Útil para validar antes de executar a limpeza real.

#### Por Que Existe
- **Segurança:** Permite verificar o que será removido antes de confirmar
- **Planejamento:** Ajuda a estimar o impacto da limpeza
- **Auditoria preventiva:** Evita remoções acidentais de dados importantes

#### Código SQL

```sql
DELIMITER //

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

DELIMITER ;
```

#### Exemplo de Uso
```sql
-- Ver o que seria removido com 7 dias
CALL sp_PreviewLimpeza(7);

-- Ver o que seria removido com 30 dias
CALL sp_PreviewLimpeza(30);
```

---

### 5. `sp_HistoricoLimpeza`

**Localização:** `AvaliacaoSimulacoes`
**Parâmetro:** `p_Limite INT` (número de registros a retornar)

#### Como Funciona
Retorna o histórico das últimas limpezas executadas, mostrando quantos registros foram removidos e quando.

#### Por Que Existe
- **Auditoria:** Rastreia todas as operações de limpeza realizadas
- **Monitoramento:** Permite verificar se a limpeza está funcionando corretamente
- **Análise de tendências:** Identifica padrões de acúmulo de dados

#### Código SQL

```sql
DELIMITER //

DROP PROCEDURE IF EXISTS sp_HistoricoLimpeza //

CREATE PROCEDURE sp_HistoricoLimpeza(
    IN p_Limite INT
)
BEGIN
    IF p_Limite IS NULL OR p_Limite <= 0 THEN
        SET p_Limite = 30;  -- Padrão: 30 registros
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
```

#### Exemplo de Uso
```sql
-- Ver últimas 10 limpezas
CALL sp_HistoricoLimpeza(10);

-- Ver todas as limpezas (padrão: 30)
CALL sp_HistoricoLimpeza(NULL);

-- Ver última limpeza
SELECT * FROM Log_Limpeza ORDER BY DataLimpeza DESC LIMIT 1;
```

---

## Sistema de Limpeza Automática

### Arquitetura

O sistema de limpeza automática opera em três camadas:

1. **Tabela de Log:** `Log_Limpeza` - Registra histórico de limpezas
2. **Procedures:** `sp_LimparDadosAntigos`, `sp_PreviewLimpeza`, `sp_HistoricoLimpeza`
3. **Event Scheduler:** `evt_LimpezaAutomatica` - Executa limpeza diária

### Tabela Log_Limpeza

```sql
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
```

### Fluxo de Limpeza

```
┌─────────────────────────────────────────────────────────────┐
│                   INÍCIO DA LIMPEZA                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  1. Calcular data limite (NOW - p_DiasRetencao)            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Contar registros que serão removidos                    │
│     - Simulações, Corpos, Avaliações, etc.                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                   ┌────────────────┐
                   │ Tem dados      │───── NÃO ────┐
                   │ antigos?       │              │
                   └────────────────┘              │
                            │                       │
                           SIM                      │
                            │                       │
                            ▼                       ▼
┌─────────────────────────────────────┐  ┌──────────────────┐
│  3. START TRANSACTION               │  │ Registrar no log │
│                                     │  │ "Nenhuma         │
│  4. DELETE Status_Avaliacoes        │  │  remoção"        │
│  5. DELETE Historico_Exportacoes    │  └──────────────────┘
│  6. DELETE Corpos_Finais            │
│  7. DELETE Resultados_Finais        │
│  8. DELETE Simulacoes_Avaliadas     │
│                                     │
│  9. COMMIT                          │
└─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  10. Registrar no log (quantidades removidas, tempo, etc.)  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  11. OPTIMIZE TABLE (liberar espaço em disco)               │
│      - Simulacoes_Avaliadas                                 │
│      - Resultados_Finais                                    │
│      - Corpos_Finais                                        │
│      - Status_Avaliacoes                                    │
│      - Historico_Exportacoes                                │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  12. Retornar resumo da operação                            │
└─────────────────────────────────────────────────────────────┘
```

### Política de Retenção

- **Padrão:** 7 dias (1 semana)
- **Dados removidos:** Apenas do banco `AvaliacaoSimulacoes`
- **Dados preservados:** Dados originais no `SimulacaoCorpos` são mantidos

### Ordem de Remoção (Respeitando Foreign Keys)

1. **Status_Avaliacoes** (depende de Simulacoes_Avaliadas)
2. **Historico_Exportacoes** (depende de Simulacoes_Avaliadas)
3. **Corpos_Finais** (depende de Resultados_Finais)
4. **Resultados_Finais** (depende de Simulacoes_Avaliadas)
5. **Simulacoes_Avaliadas** (tabela principal)

### Otimização Após Limpeza

Após remover os dados, o sistema executa `OPTIMIZE TABLE` em todas as tabelas afetadas. Isso:

- **Libera espaço em disco:** Remove fragmentação
- **Reorganiza índices:** Melhora performance de consultas
- **Atualiza estatísticas:** Otimiza planos de execução

---

## Events Agendados

### 1. `evt_LimpezaAutomatica`

**Localização:** `AvaliacaoSimulacoes`
**Frequência:** Diária (todo dia à meia-noite)
**Ação:** Executa `sp_LimparDadosAntigos(7)`

#### Configuração

```sql
SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS evt_LimpezaAutomatica;

CREATE EVENT evt_LimpezaAutomatica
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)  -- Próxima meia-noite
DO
    CALL sp_LimparDadosAntigos(7);  -- Remover dados com mais de 7 dias
```

#### Como Funciona
- **Agendamento:** Executa diariamente à meia-noite
- **Automático:** Não requer intervenção manual
- **Parâmetro fixo:** Remove dados com mais de 7 dias
- **Pode ser ajustado:** Modificar o valor `7` para alterar a política de retenção

---

### 2. `evt_RetryExportacoesFalhadas`

**Localização:** `SimulacaoCorpos`
**Frequência:** A cada 1 hora
**Ação:** Executa `sp_RetentarExportacoesFalhadas()`

#### Configuração

```sql
SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS evt_RetryExportacoesFalhadas;

CREATE EVENT evt_RetryExportacoesFalhadas
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP
DO
    CALL sp_RetentarExportacoesFalhadas();
```

#### Como Funciona
- **Agendamento:** Executa a cada hora
- **Resiliência:** Reprocessa exportações falhadas automaticamente
- **Início imediato:** Começa a executar assim que é criado

---

## Verificação e Monitoramento

### Verificar Status do Event Scheduler

```sql
-- Ver se o Event Scheduler está ativo
SHOW VARIABLES LIKE 'event_scheduler';

-- Resultado esperado: ON
```

### Listar Events Ativos

```sql
SELECT
    EVENT_SCHEMA AS Schema,
    EVENT_NAME AS Evento,
    STATUS AS Status,
    EVENT_TYPE AS Tipo,
    INTERVAL_VALUE AS Intervalo,
    INTERVAL_FIELD AS Unidade,
    STARTS AS Inicio,
    ENDS AS Fim
FROM information_schema.EVENTS
WHERE EVENT_SCHEMA IN ('SimulacaoCorpos', 'AvaliacaoSimulacoes')
ORDER BY EVENT_SCHEMA, EVENT_NAME;
```

### Verificar Último Log de Limpeza

```sql
SELECT
    DataLimpeza,
    QtdSimulacoesRemovidas,
    QtdCorposRemovidos,
    QtdAvaliacoesRemovidas,
    TempoExecucao,
    Observacoes
FROM Log_Limpeza
ORDER BY DataLimpeza DESC
LIMIT 1;
```

### Consultas Úteis para Monitoramento

```sql
-- Ver estatísticas de dados armazenados
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
```

```sql
-- Ver tamanho das tabelas
SELECT
    table_name AS Tabela,
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS TamanhoMB,
    table_rows AS LinhasAproximadas
FROM information_schema.TABLES
WHERE table_schema = 'AvaliacaoSimulacoes'
ORDER BY (data_length + index_length) DESC;
```

```sql
-- Ver simulações mais antigas
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
```

---

## Resumo Executivo

### Triggers
| Nome | Banco | Tabela | Evento | Função |
|------|-------|--------|--------|--------|
| `trg_ExportarAntesNovaSimulacao` | SimulacaoCorpos | Simulacao | AFTER INSERT | Exporta simulação anterior ao criar nova |

### Procedures Principais
| Nome | Banco | Parâmetros | Função |
|------|-------|------------|--------|
| `sp_ExportarSimulacaoParaAvaliador` | SimulacaoCorpos | `p_NumSimulacao` | Exporta simulação para o avaliador |
| `sp_RetentarExportacoesFalhadas` | SimulacaoCorpos | - | Reprocessa exportações falhadas |
| `sp_LimparDadosAntigos` | AvaliacaoSimulacoes | `p_DiasRetencao` | Remove dados antigos |
| `sp_PreviewLimpeza` | AvaliacaoSimulacoes | `p_DiasRetencao` | Preview de limpeza |
| `sp_HistoricoLimpeza` | AvaliacaoSimulacoes | `p_Limite` | Ver histórico de limpezas |

### Events Automáticos
| Nome | Banco | Frequência | Ação |
|------|-------|------------|------|
| `evt_LimpezaAutomatica` | AvaliacaoSimulacoes | Diária (meia-noite) | Remove dados >7 dias |
| `evt_RetryExportacoesFalhadas` | SimulacaoCorpos | A cada 1 hora | Retenta exportações falhadas |

---

## Comandos Rápidos

```sql
-- EXPORTAÇÃO
CALL sp_ExportarSimulacaoParaAvaliador(5);  -- Exportar simulação 5
CALL sp_RetentarExportacoesFalhadas();      -- Retentar falhas

-- LIMPEZA
CALL sp_PreviewLimpeza(7);                  -- Ver o que seria removido
CALL sp_LimparDadosAntigos(7);              -- Executar limpeza
CALL sp_HistoricoLimpeza(10);               -- Ver últimas 10 limpezas

-- MONITORAMENTO
SHOW VARIABLES LIKE 'event_scheduler';      -- Ver se events estão ativos
SELECT * FROM Log_Limpeza ORDER BY DataLimpeza DESC LIMIT 5;
SELECT * FROM Controle_Exportacao WHERE StatusExportacao = 'FALHA';
```

---

**Última Atualização:** 2025-11-21
