-- ========================================================================
-- SETUP COMPLETO DO SISTEMA DE SIMULAÇÕES GRAVITACIONAIS
-- ========================================================================
-- Este script configura todo o sistema de banco de dados integrado:
-- 1. Schema do Gerador (SimulacaoCorpos)
-- 2. Schema do Avaliador (AvaliacaoSimulacoes)
-- 3. Integração entre os schemas
-- 4. Rotinas de limpeza automática
-- ========================================================================

-- ========================================================================
-- PASSO 1: CRIAR SCHEMA DO GERADOR
-- ========================================================================

SOURCE mysql_database_setup.sql;

-- ========================================================================
-- PASSO 2: CRIAR SCHEMA DO AVALIADOR
-- ========================================================================

SOURCE schema_avaliador.sql;

-- ========================================================================
-- PASSO 3: CONFIGURAR INTEGRAÇÃO
-- ========================================================================

SOURCE integracao_gerador_avaliador.sql;

-- ========================================================================
-- PASSO 4: CONFIGURAR ROTINA DE LIMPEZA
-- ========================================================================

SOURCE rotina_limpeza.sql;

-- ========================================================================
-- PASSO 5: ATIVAR EVENT SCHEDULER
-- ========================================================================

SET GLOBAL event_scheduler = ON;

-- ========================================================================
-- PASSO 6: VERIFICAR INSTALAÇÃO
-- ========================================================================

-- Verificar schemas criados
SELECT
    SCHEMA_NAME AS NomeBanco,
    DEFAULT_CHARACTER_SET_NAME AS Charset,
    DEFAULT_COLLATION_NAME AS Collation
FROM information_schema.SCHEMATA
WHERE SCHEMA_NAME IN ('SimulacaoCorpos', 'AvaliacaoSimulacoes');

-- Verificar tabelas do Gerador
SELECT
    TABLE_NAME AS Tabela,
    TABLE_TYPE AS Tipo,
    TABLE_ROWS AS LinhasAprox,
    ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) AS TamanhoMB
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'SimulacaoCorpos'
ORDER BY TABLE_NAME;

-- Verificar tabelas do Avaliador
SELECT
    TABLE_NAME AS Tabela,
    TABLE_TYPE AS Tipo,
    TABLE_ROWS AS LinhasAprox,
    ROUND(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) AS TamanhoMB
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'AvaliacaoSimulacoes'
ORDER BY TABLE_NAME;

-- Verificar stored procedures
SELECT
    ROUTINE_SCHEMA AS Schema,
    ROUTINE_NAME AS Procedure,
    ROUTINE_TYPE AS Tipo
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA IN ('SimulacaoCorpos', 'AvaliacaoSimulacoes')
ORDER BY ROUTINE_SCHEMA, ROUTINE_NAME;

-- Verificar triggers
SELECT
    TRIGGER_SCHEMA AS Schema,
    TRIGGER_NAME AS Trigger,
    EVENT_MANIPULATION AS Evento,
    EVENT_OBJECT_TABLE AS Tabela
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'SimulacaoCorpos'
ORDER BY TRIGGER_NAME;

-- Verificar eventos agendados
SELECT
    EVENT_SCHEMA AS Schema,
    EVENT_NAME AS Evento,
    STATUS AS Status,
    EVENT_TYPE AS Tipo,
    INTERVAL_VALUE AS Intervalo,
    INTERVAL_FIELD AS Unidade
FROM information_schema.EVENTS
WHERE EVENT_SCHEMA IN ('SimulacaoCorpos', 'AvaliacaoSimulacoes')
ORDER BY EVENT_SCHEMA, EVENT_NAME;

-- ========================================================================
-- MENSAGEM FINAL
-- ========================================================================

SELECT '========================================' AS '';
SELECT 'SETUP COMPLETO EXECUTADO COM SUCESSO!' AS '';
SELECT '========================================' AS '';
SELECT '' AS '';
SELECT 'Schemas criados:' AS '';
SELECT '  - SimulacaoCorpos (Gerador)' AS '';
SELECT '  - AvaliacaoSimulacoes (Avaliador)' AS '';
SELECT '' AS '';
SELECT 'Funcionalidades ativas:' AS '';
SELECT '  ✓ Exportação automática ao iniciar nova simulação' AS '';
SELECT '  ✓ Retry de exportações falhadas (a cada 1 hora)' AS '';
SELECT '  ✓ Limpeza automática de dados antigos (diária)' AS '';
SELECT '  ✓ Filtro: apenas simulações com 3+ corpos finais' AS '';
SELECT '  ✓ Transações para garantir atomicidade' AS '';
SELECT '  ✓ Índices otimizados para performance' AS '';
SELECT '' AS '';
SELECT 'Próximos passos:' AS '';
SELECT '  1. Execute: SOURCE dados_teste.sql' AS '';
SELECT '  2. Simule novas simulações no Gerador' AS '';
SELECT '  3. Monitore exportações: SELECT * FROM SimulacaoCorpos.Controle_Exportacao;' AS '';
SELECT '  4. Verifique avaliador: SELECT * FROM AvaliacaoSimulacoes.Simulacoes_Avaliadas;' AS '';
SELECT '' AS '';
SELECT '========================================' AS '';

-- ========================================================================
-- FIM DO SETUP
-- ========================================================================
