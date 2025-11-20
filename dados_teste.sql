-- ========================================================================
-- DADOS DE TESTE PARA O SISTEMA DE SIMULAÇÕES
-- ========================================================================
-- Este script cria dados de teste para demonstrar:
-- 1. Simulações completas com vários corpos
-- 2. Exportação automática para o Avaliador
-- 3. Simulações com menos de 3 corpos (não exportadas)
-- 4. Diferentes cenários de teste
-- ========================================================================

USE SimulacaoCorpos;

-- ========================================================================
-- CENÁRIO 1: Simulação com 5 corpos finais (será exportada)
-- ========================================================================

-- Criar simulação 2
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES ('2025-11-13 08:00:00', 250, 150000, 7200);

SET @sim2 = LAST_INSERT_ID();

-- Iteração inicial (0)
INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim2, 0);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim2, 0, 'Estrela_Principal', 1.989e30, 0, 0, 0, 0, 1408),
    (@sim2, 0, 'Planeta_A', 5.972e24, 1.5e11, 0, 0, 29780, 5514),
    (@sim2, 0, 'Planeta_B', 4.867e24, -2.0e11, 0, 0, -25000, 5243),
    (@sim2, 0, 'Planeta_C', 6.417e23, 0, 2.5e11, 20000, 0, 3933),
    (@sim2, 0, 'Lua_1', 7.342e22, 1.5e11 + 3.844e8, 0, 0, 29780 + 1022, 3344);

-- Iteração final (150000)
INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim2, 150000);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim2, 150000, 'Estrela_Principal', 1.989e30, 1000, 500, 10, 5, 1408),
    (@sim2, 150000, 'Planeta_A', 5.972e24, 1.6e11, 2.0e10, 15000, 28000, 5514),
    (@sim2, 150000, 'Planeta_B', 4.867e24, -2.1e11, -1.5e10, -5000, -24000, 5243),
    (@sim2, 150000, 'Planeta_C', 6.417e23, 5.0e10, 2.4e11, 22000, -3000, 3933),
    (@sim2, 150000, 'Lua_1', 7.342e22, 1.62e11, 2.05e10, 15500, 28500, 3344);

-- ========================================================================
-- CENÁRIO 2: Simulação com apenas 2 corpos finais (NÃO será exportada)
-- ========================================================================

-- Criar simulação 3
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES ('2025-11-13 10:00:00', 200, 200000, 9600);

SET @sim3 = LAST_INSERT_ID();

-- Iteração inicial (0)
INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim3, 0);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim3, 0, 'Estrela_1', 1.989e30, -5.0e10, 0, 0, 15000, 1408),
    (@sim3, 0, 'Estrela_2', 1.5e30, 5.0e10, 0, 0, -15000, 1200),
    (@sim3, 0, 'Planeta_X', 3.0e24, 0, 1.0e11, -20000, 0, 4500);

-- Iteração final (200000) - apenas 2 corpos (colidiram/fundiram)
INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim3, 200000);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim3, 200000, 'Estrela_Binaria_A', 2.0e30, -3.0e10, 5.0e9, 5000, 12000, 1350),
    (@sim3, 200000, 'Estrela_Binaria_B', 1.489e30, 3.5e10, -4.0e9, -6000, -13000, 1180);

-- ========================================================================
-- CENÁRIO 3: Simulação com 3 corpos finais (limite mínimo - será exportada)
-- ========================================================================

-- Criar simulação 4
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES ('2025-11-13 12:00:00', 300, 250000, 12000);

SET @sim4 = LAST_INSERT_ID();

-- Iteração inicial (0)
INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim4, 0);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim4, 0, 'Sol_Central', 2.5e30, 0, 0, 0, 0, 1500),
    (@sim4, 0, 'Gigante_Gasoso_1', 1.898e27, 7.78e11, 0, 0, 13070, 1326),
    (@sim4, 0, 'Gigante_Gasoso_2', 5.683e26, 0, -1.43e12, -9690, 0, 687),
    (@sim4, 0, 'Planeta_Rochoso', 6.0e24, 1.0e11, 0, 0, 30000, 5500);

-- Iteração final (250000) - exatamente 3 corpos
INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim4, 250000);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim4, 250000, 'Sol_Central', 2.5e30, 5000, -2000, 50, -20, 1500),
    (@sim4, 250000, 'Gigante_Gasoso_1', 1.898e27, 8.0e11, 1.5e11, 5000, 12000, 1326),
    (@sim4, 250000, 'Gigante_Gasoso_2', 5.683e26, -2.0e11, -1.5e12, -8000, -9000, 687);

-- ========================================================================
-- CENÁRIO 4: Simulação com 8 corpos finais (sistema complexo)
-- ========================================================================

-- Criar simulação 5
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES ('2025-11-13 14:00:00', 350, 300000, 15000);

SET @sim5 = LAST_INSERT_ID();

-- Iteração inicial (0)
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

-- Iteração final (300000) - 8 corpos sobreviveram
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

-- ========================================================================
-- CENÁRIO 5: Simulação antiga (mais de 1 semana)
-- ========================================================================

-- Criar simulação 6 (será limpa automaticamente)
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES ('2025-11-06 08:00:00', 220, 180000, 8400);

SET @sim6 = LAST_INSERT_ID();

-- Iteração inicial
INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim6, 0);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim6, 0, 'Estrela_Beta', 1.5e30, 0, 0, 0, 0, 1200),
    (@sim6, 0, 'Planeta_Alpha', 4.0e24, 1.2e11, 0, 0, 28000, 5000),
    (@sim6, 0, 'Planeta_Beta', 3.5e24, -1.5e11, 0, 0, -25000, 4800),
    (@sim6, 0, 'Planeta_Gamma', 2.8e24, 0, 1.8e11, 22000, 0, 4600);

-- Iteração final
INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim6, 180000);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim6, 180000, 'Estrela_Beta', 1.5e30, 1500, 800, 15, 8, 1200),
    (@sim6, 180000, 'Planeta_Alpha', 4.0e24, 1.25e11, 2.0e10, 26000, 29000, 5000),
    (@sim6, 180000, 'Planeta_Beta', 3.5e24, -1.6e11, -1.0e10, -4000, -24000, 4800),
    (@sim6, 180000, 'Planeta_Gamma', 2.8e24, 5.0e10, 1.85e11, 23000, -2000, 4600);

-- ========================================================================
-- VERIFICAÇÕES
-- ========================================================================

-- Mostrar todas as simulações criadas
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

-- Mostrar status de exportação
SELECT
    ce.NumSimulacao,
    s.DataSimulacao,
    ce.StatusExportacao,
    ce.QtdCorposFinais,
    ce.MensagemErro
FROM Controle_Exportacao ce
INNER JOIN Simulacao s ON ce.NumSimulacao = s.NumSimulacao
ORDER BY ce.NumSimulacao;

-- ========================================================================
-- EXECUTAR EXPORTAÇÕES PENDENTES
-- ========================================================================

-- Exportar simulações manualmente (normalmente feito automaticamente pelo trigger)
CALL sp_ExportarSimulacaoParaAvaliador(1);
CALL sp_ExportarSimulacaoParaAvaliador(2);
CALL sp_ExportarSimulacaoParaAvaliador(3);
CALL sp_ExportarSimulacaoParaAvaliador(4);
CALL sp_ExportarSimulacaoParaAvaliador(5);
CALL sp_ExportarSimulacaoParaAvaliador(6);

-- ========================================================================
-- VERIFICAR DADOS NO AVALIADOR
-- ========================================================================

USE AvaliacaoSimulacoes;

-- Mostrar simulações importadas
SELECT
    NumSimulacao,
    DataSimulacao,
    DataImportacao,
    QtdCorposInicial,
    QtdCorposFinais,
    StatusAvaliacao
FROM Simulacoes_Avaliadas
ORDER BY NumSimulacao;

-- Mostrar estatísticas
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
-- CRIAR ALGUMAS AVALIAÇÕES DE EXEMPLO
-- ========================================================================

-- Avaliar simulação 2 (5 corpos)
CALL sp_AvaliarSimulacao(2, 'Dr. João Silva', 4, 'Sistema estável com órbitas interessantes');

-- Avaliar simulação 4 (3 corpos)
CALL sp_AvaliarSimulacao(4, 'Dra. Maria Santos', 5, 'Configuração rara de 3 corpos em equilíbrio');

-- Avaliar simulação 5 (8 corpos)
CALL sp_AvaliarSimulacao(5, 'Dr. João Silva', 3, 'Sistema solar simulado com alta precisão');
CALL sp_AvaliarSimulacao(5, 'Prof. Carlos Lima', 4, 'Boa conservação de energia e momento angular');

-- ========================================================================
-- VERIFICAÇÕES FINAIS
-- ========================================================================

-- Ver simulações com suas avaliações
SELECT * FROM vw_Simulacoes_Completas ORDER BY NumSimulacao;

-- Ver simulações de interesse científico
SELECT * FROM vw_Simulacoes_Interesse_Cientifico;

-- Ver simulações pendentes
SELECT * FROM vw_Simulacoes_Pendentes;

-- ========================================================================
-- MENSAGEM FINAL
-- ========================================================================

SELECT '========================================' AS '';
SELECT 'DADOS DE TESTE CRIADOS COM SUCESSO!' AS '';
SELECT '========================================' AS '';
SELECT '' AS '';
SELECT 'Resumo dos cenários criados:' AS '';
SELECT '  - Simulação 1: 3 corpos (exemplo original)' AS '';
SELECT '  - Simulação 2: 5 corpos finais (EXPORTADA)' AS '';
SELECT '  - Simulação 3: 2 corpos finais (NÃO EXPORTADA)' AS '';
SELECT '  - Simulação 4: 3 corpos finais (EXPORTADA)' AS '';
SELECT '  - Simulação 5: 8 corpos finais (EXPORTADA)' AS '';
SELECT '  - Simulação 6: 4 corpos, >7 dias (será limpa)' AS '';
SELECT '' AS '';
SELECT 'Total exportadas: 4 simulações' AS '';
SELECT 'Avaliações criadas: 4 avaliações' AS '';
SELECT '' AS '';
SELECT '========================================' AS '';

-- ========================================================================
-- FIM DOS DADOS DE TESTE
-- ========================================================================
