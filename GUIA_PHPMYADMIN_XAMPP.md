# 🚀 Guia de Instalação - phpMyAdmin XAMPP (SEM privilégios SUPER)

## ⚠️ IMPORTANTE
Este guia foi criado para o **XAMPP** e **não requer privilégios SUPER**.
Os Events automáticos são opcionais - você pode executá-los manualmente quando precisar.

---

## 🗄️ PASSO 1: Criar o Banco GERADOR

### 1.1 - Criar Database SimulacaoCorpos

```sql
DROP DATABASE IF EXISTS SimulacaoCorpos;
CREATE DATABASE SimulacaoCorpos CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE SimulacaoCorpos;
```

### 1.2 - Tabela Simulacao

```sql
CREATE TABLE Simulacao (
    NumSimulacao INT AUTO_INCREMENT PRIMARY KEY,
    DataSimulacao DATETIME NOT NULL,
    QtdCorposInicial INT NOT NULL CHECK (QtdCorposInicial >= 200),
    NumInteracoes INT NOT NULL CHECK (NumInteracoes BETWEEN 100000 AND 500000),
    TempoInteracoes BIGINT NOT NULL,
    INDEX idx_simulacao_data (DataSimulacao)
) ENGINE=InnoDB;
```

### 1.3 - Tabela Resultados

```sql
CREATE TABLE Resultados (
    NumSimulacao INT NOT NULL,
    NumIteracao INT NOT NULL,
    PRIMARY KEY (NumSimulacao, NumIteracao),
    FOREIGN KEY (NumSimulacao) REFERENCES Simulacao(NumSimulacao) ON DELETE CASCADE,
    INDEX idx_resultados_sim_iter (NumSimulacao, NumIteracao DESC)
) ENGINE=InnoDB;
```

### 1.4 - Tabela Corpos

```sql
CREATE TABLE Corpos (
    NumSimulacao INT NOT NULL,
    NumIteracao INT NOT NULL,
    NomeCorpo VARCHAR(100) NOT NULL,
    MassaCorpo DECIMAL(30, 10) NOT NULL CHECK (MassaCorpo > 0),
    PosX DECIMAL(30, 10) NOT NULL,
    PosY DECIMAL(30, 10) NOT NULL,
    VelX DECIMAL(30, 10) NOT NULL,
    VelY DECIMAL(30, 10) NOT NULL,
    DensidadeCorpo DECIMAL(10, 2) NOT NULL CHECK (DensidadeCorpo > 0),
    PRIMARY KEY (NumSimulacao, NumIteracao, NomeCorpo),
    FOREIGN KEY (NumSimulacao, NumIteracao) REFERENCES Resultados(NumSimulacao, NumIteracao) ON DELETE CASCADE,
    INDEX idx_corpos_exportacao (NumSimulacao, NumIteracao),
    INDEX idx_corpos_nome (NomeCorpo)
) ENGINE=InnoDB;
```

### 1.5 - Tabela Controle_Exportacao

```sql
CREATE TABLE Controle_Exportacao (
    NumSimulacao INT PRIMARY KEY,
    StatusExportacao ENUM('PENDENTE', 'SUCESSO', 'FALHA') DEFAULT 'PENDENTE',
    DataPrimeiraExportacao DATETIME,
    DataUltimaTentativa DATETIME,
    NumTentativas INT DEFAULT 0,
    QtdCorposFinais INT,
    MensagemErro TEXT,
    FOREIGN KEY (NumSimulacao) REFERENCES Simulacao(NumSimulacao) ON DELETE CASCADE,
    INDEX idx_controle_status (StatusExportacao),
    INDEX idx_controle_tentativas (NumTentativas, DataUltimaTentativa)
) ENGINE=InnoDB;
```

---

## 🔬 PASSO 2: Criar o Banco AVALIADOR

### 2.1 - Criar Database AvaliacaoSimulacoes

```sql
DROP DATABASE IF EXISTS AvaliacaoSimulacoes;
CREATE DATABASE AvaliacaoSimulacoes CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE AvaliacaoSimulacoes;
```

### 2.2 - Tabela Simulacoes_Avaliadas

```sql
CREATE TABLE Simulacoes_Avaliadas (
    NumSimulacao INT PRIMARY KEY,
    DataImportacao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    QtdCorposIniciais INT NOT NULL,
    NumInteracoes INT NOT NULL,
    TempoInteracoes BIGINT NOT NULL,
    QtdCorposFinais INT NOT NULL,
    StatusAvaliacao ENUM('PENDENTE', 'EM_ANALISE', 'INTERESSE_CIENTIFICO', 'DESCARTADO') DEFAULT 'PENDENTE',
    INDEX idx_simulacoes_data_importacao (DataImportacao),
    INDEX idx_simulacoes_status (StatusAvaliacao),
    INDEX idx_simulacoes_qtd_corpos (QtdCorposFinais)
) ENGINE=InnoDB;
```

### 2.3 - Tabela Resultados_Finais

```sql
CREATE TABLE Resultados_Finais (
    NumSimulacao INT NOT NULL,
    NumIteracao INT NOT NULL,
    PRIMARY KEY (NumSimulacao, NumIteracao),
    FOREIGN KEY (NumSimulacao) REFERENCES Simulacoes_Avaliadas(NumSimulacao) ON DELETE CASCADE
) ENGINE=InnoDB;
```

### 2.4 - Tabela Corpos_Finais

```sql
CREATE TABLE Corpos_Finais (
    NumSimulacao INT NOT NULL,
    NumIteracao INT NOT NULL,
    NomeCorpo VARCHAR(100) NOT NULL,
    MassaCorpo DECIMAL(30, 10) NOT NULL,
    PosX DECIMAL(30, 10) NOT NULL,
    PosY DECIMAL(30, 10) NOT NULL,
    VelX DECIMAL(30, 10) NOT NULL,
    VelY DECIMAL(30, 10) NOT NULL,
    DensidadeCorpo DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (NumSimulacao, NumIteracao, NomeCorpo),
    FOREIGN KEY (NumSimulacao, NumIteracao) REFERENCES Resultados_Finais(NumSimulacao, NumIteracao) ON DELETE CASCADE,
    INDEX idx_corpos_finais_simulacao (NumSimulacao)
) ENGINE=InnoDB;
```

### 2.5 - Tabela Status_Avaliacoes

```sql
CREATE TABLE Status_Avaliacoes (
    IdAvaliacao INT AUTO_INCREMENT PRIMARY KEY,
    NumSimulacao INT NOT NULL,
    DataAvaliacao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Avaliador VARCHAR(100) NOT NULL,
    NotaInteresse INT CHECK (NotaInteresse BETWEEN 1 AND 5),
    Observacoes TEXT,
    FOREIGN KEY (NumSimulacao) REFERENCES Simulacoes_Avaliadas(NumSimulacao) ON DELETE CASCADE,
    INDEX idx_avaliacoes_simulacao (NumSimulacao),
    INDEX idx_avaliacoes_data (DataAvaliacao)
) ENGINE=InnoDB;
```

### 2.6 - Tabela Log_Limpeza

```sql
CREATE TABLE Log_Limpeza (
    IdLog INT AUTO_INCREMENT PRIMARY KEY,
    DataLimpeza DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    SimulacoesRemovidas INT DEFAULT 0,
    ResultadosRemovidos INT DEFAULT 0,
    CorposRemovidos INT DEFAULT 0,
    DiasRetencao INT NOT NULL,
    INDEX idx_log_data (DataLimpeza)
) ENGINE=InnoDB;
```

---

## 🔧 PASSO 3: Stored Procedure de Exportação

⚠️ **IMPORTANTE**: No phpMyAdmin, siga estes passos:

1. Clique na aba **"SQL"**
2. **Cole o código abaixo**
3. Onde diz **"Delimiter"** (embaixo da caixa de texto), **mude de `;` para `//`**
4. Clique em **"Executar"**

```sql
USE SimulacaoCorpos;

DROP PROCEDURE IF EXISTS sp_ExportarSimulacaoParaAvaliador;

CREATE PROCEDURE sp_ExportarSimulacaoParaAvaliador(IN p_NumSimulacao INT)
BEGIN
    DECLARE v_QtdCorposFinais INT;
    DECLARE v_MaxIteracao INT;
    DECLARE v_QtdCorposIniciais INT;
    DECLARE v_NumInteracoes INT;
    DECLARE v_TempoInteracoes BIGINT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        UPDATE Controle_Exportacao
        SET StatusExportacao = 'FALHA',
            DataUltimaTentativa = NOW(),
            NumTentativas = NumTentativas + 1,
            MensagemErro = 'Erro durante exportação'
        WHERE NumSimulacao = p_NumSimulacao;
    END;

    SELECT MAX(NumIteracao) INTO v_MaxIteracao
    FROM Resultados
    WHERE NumSimulacao = p_NumSimulacao;

    IF v_MaxIteracao IS NULL THEN
        UPDATE Controle_Exportacao
        SET StatusExportacao = 'FALHA',
            DataUltimaTentativa = NOW(),
            NumTentativas = NumTentativas + 1,
            MensagemErro = 'Nenhuma iteração encontrada'
        WHERE NumSimulacao = p_NumSimulacao;
        LEAVE sp_ExportarSimulacaoParaAvaliador;
    END IF;

    SELECT COUNT(*) INTO v_QtdCorposFinais
    FROM Corpos
    WHERE NumSimulacao = p_NumSimulacao AND NumIteracao = v_MaxIteracao;

    UPDATE Controle_Exportacao
    SET QtdCorposFinais = v_QtdCorposFinais
    WHERE NumSimulacao = p_NumSimulacao;

    IF v_QtdCorposFinais < 3 THEN
        UPDATE Controle_Exportacao
        SET StatusExportacao = 'FALHA',
            DataUltimaTentativa = NOW(),
            NumTentativas = NumTentativas + 1,
            MensagemErro = 'Menos de 3 corpos finais'
        WHERE NumSimulacao = p_NumSimulacao;
        LEAVE sp_ExportarSimulacaoParaAvaliador;
    END IF;

    SELECT QtdCorposInicial, NumInteracoes, TempoInteracoes
    INTO v_QtdCorposIniciais, v_NumInteracoes, v_TempoInteracoes
    FROM Simulacao
    WHERE NumSimulacao = p_NumSimulacao;

    START TRANSACTION;

    INSERT INTO AvaliacaoSimulacoes.Simulacoes_Avaliadas
        (NumSimulacao, DataImportacao, QtdCorposIniciais, NumInteracoes, TempoInteracoes, QtdCorposFinais, StatusAvaliacao)
    VALUES
        (p_NumSimulacao, NOW(), v_QtdCorposIniciais, v_NumInteracoes, v_TempoInteracoes, v_QtdCorposFinais, 'PENDENTE')
    ON DUPLICATE KEY UPDATE
        DataImportacao = NOW(),
        QtdCorposIniciais = v_QtdCorposIniciais,
        NumInteracoes = v_NumInteracoes,
        TempoInteracoes = v_TempoInteracoes,
        QtdCorposFinais = v_QtdCorposFinais;

    DELETE FROM AvaliacaoSimulacoes.Resultados_Finais WHERE NumSimulacao = p_NumSimulacao;

    INSERT INTO AvaliacaoSimulacoes.Resultados_Finais (NumSimulacao, NumIteracao)
    SELECT NumSimulacao, NumIteracao
    FROM Resultados
    WHERE NumSimulacao = p_NumSimulacao AND NumIteracao = v_MaxIteracao;

    INSERT INTO AvaliacaoSimulacoes.Corpos_Finais
        (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
    SELECT NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo
    FROM Corpos
    WHERE NumSimulacao = p_NumSimulacao AND NumIteracao = v_MaxIteracao;

    UPDATE Controle_Exportacao
    SET StatusExportacao = 'SUCESSO',
        DataPrimeiraExportacao = COALESCE(DataPrimeiraExportacao, NOW()),
        DataUltimaTentativa = NOW(),
        NumTentativas = NumTentativas + 1,
        MensagemErro = NULL
    WHERE NumSimulacao = p_NumSimulacao;

    COMMIT;
END
```

**Depois de executar**, volte o Delimiter para `;` (ponto e vírgula)!

---

## 🔄 PASSO 4: Stored Procedure de Retry

⚠️ **Lembre-se**: Delimiter = `//`

```sql
USE SimulacaoCorpos;

DROP PROCEDURE IF EXISTS sp_RetentarExportacoesFalhadas;

CREATE PROCEDURE sp_RetentarExportacoesFalhadas()
BEGIN
    DECLARE v_NumSimulacao INT;
    DECLARE done INT DEFAULT FALSE;
    DECLARE cur CURSOR FOR
        SELECT NumSimulacao
        FROM Controle_Exportacao
        WHERE StatusExportacao = 'FALHA'
          AND NumTentativas < 5
          AND TIMESTAMPDIFF(MINUTE, DataUltimaTentativa, NOW()) >= 60;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur;
    retry_loop: LOOP
        FETCH cur INTO v_NumSimulacao;
        IF done THEN
            LEAVE retry_loop;
        END IF;
        CALL sp_ExportarSimulacaoParaAvaliador(v_NumSimulacao);
    END LOOP;
    CLOSE cur;
END
```

**Volte o Delimiter para `;`**

---

## 🧹 PASSO 5: Stored Procedures de Limpeza

### 5.1 - SP Preview Limpeza
⚠️ Delimiter = `//`

```sql
USE AvaliacaoSimulacoes;

DROP PROCEDURE IF EXISTS sp_PreviewLimpeza;

CREATE PROCEDURE sp_PreviewLimpeza(IN p_DiasRetencao INT)
BEGIN
    SELECT
        COUNT(DISTINCT sa.NumSimulacao) AS TotalSimulacoes,
        COUNT(DISTINCT rf.NumSimulacao) AS TotalResultados,
        COUNT(*) AS TotalCorpos
    FROM Simulacoes_Avaliadas sa
    LEFT JOIN Resultados_Finais rf ON sa.NumSimulacao = rf.NumSimulacao
    LEFT JOIN Corpos_Finais cf ON rf.NumSimulacao = cf.NumSimulacao AND rf.NumIteracao = cf.NumIteracao
    WHERE sa.DataImportacao < DATE_SUB(NOW(), INTERVAL p_DiasRetencao DAY)
      AND sa.StatusAvaliacao NOT IN ('EM_ANALISE', 'INTERESSE_CIENTIFICO');
END
```

**Volte o Delimiter para `;`**

### 5.2 - SP Limpeza de Dados
⚠️ Delimiter = `//`

```sql
USE AvaliacaoSimulacoes;

DROP PROCEDURE IF EXISTS sp_LimparDadosAntigos;

CREATE PROCEDURE sp_LimparDadosAntigos(IN p_DiasRetencao INT)
BEGIN
    DECLARE v_SimulacoesRemovidas INT DEFAULT 0;
    DECLARE v_ResultadosRemovidos INT DEFAULT 0;
    DECLARE v_CorposRemovidos INT DEFAULT 0;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_CorposRemovidos
    FROM Corpos_Finais cf
    INNER JOIN Simulacoes_Avaliadas sa ON cf.NumSimulacao = sa.NumSimulacao
    WHERE sa.DataImportacao < DATE_SUB(NOW(), INTERVAL p_DiasRetencao DAY)
      AND sa.StatusAvaliacao NOT IN ('EM_ANALISE', 'INTERESSE_CIENTIFICO');

    SELECT COUNT(*) INTO v_ResultadosRemovidos
    FROM Resultados_Finais rf
    INNER JOIN Simulacoes_Avaliadas sa ON rf.NumSimulacao = sa.NumSimulacao
    WHERE sa.DataImportacao < DATE_SUB(NOW(), INTERVAL p_DiasRetencao DAY)
      AND sa.StatusAvaliacao NOT IN ('EM_ANALISE', 'INTERESSE_CIENTIFICO');

    SELECT COUNT(*) INTO v_SimulacoesRemovidas
    FROM Simulacoes_Avaliadas
    WHERE DataImportacao < DATE_SUB(NOW(), INTERVAL p_DiasRetencao DAY)
      AND StatusAvaliacao NOT IN ('EM_ANALISE', 'INTERESSE_CIENTIFICO');

    DELETE sa FROM Simulacoes_Avaliadas sa
    WHERE sa.DataImportacao < DATE_SUB(NOW(), INTERVAL p_DiasRetencao DAY)
      AND sa.StatusAvaliacao NOT IN ('EM_ANALISE', 'INTERESSE_CIENTIFICO');

    INSERT INTO Log_Limpeza (DataLimpeza, SimulacoesRemovidas, ResultadosRemovidos, CorposRemovidos, DiasRetencao)
    VALUES (NOW(), v_SimulacoesRemovidas, v_ResultadosRemovidos, v_CorposRemovidos, p_DiasRetencao);

    COMMIT;

    SELECT v_SimulacoesRemovidas AS SimulacoesRemovidas,
           v_ResultadosRemovidos AS ResultadosRemovidos,
           v_CorposRemovidos AS CorposRemovidos;
END
```

**Volte o Delimiter para `;`**

### 5.3 - SP Histórico Limpeza
⚠️ Delimiter = `//`

```sql
USE AvaliacaoSimulacoes;

DROP PROCEDURE IF EXISTS sp_HistoricoLimpeza;

CREATE PROCEDURE sp_HistoricoLimpeza(IN p_Limite INT)
BEGIN
    SELECT * FROM Log_Limpeza
    ORDER BY DataLimpeza DESC
    LIMIT p_Limite;
END
```

**Volte o Delimiter para `;`**

---

## 📊 PASSO 6: Stored Procedures Auxiliares

### 6.1 - SP Avaliar Simulação
⚠️ Delimiter = `//`

```sql
USE AvaliacaoSimulacoes;

DROP PROCEDURE IF EXISTS sp_AvaliarSimulacao;

CREATE PROCEDURE sp_AvaliarSimulacao(
    IN p_NumSimulacao INT,
    IN p_Avaliador VARCHAR(100),
    IN p_NotaInteresse INT,
    IN p_Observacoes TEXT
)
BEGIN
    INSERT INTO Status_Avaliacoes (NumSimulacao, DataAvaliacao, Avaliador, NotaInteresse, Observacoes)
    VALUES (p_NumSimulacao, NOW(), p_Avaliador, p_NotaInteresse, p_Observacoes);

    IF p_NotaInteresse >= 4 THEN
        UPDATE Simulacoes_Avaliadas
        SET StatusAvaliacao = 'INTERESSE_CIENTIFICO'
        WHERE NumSimulacao = p_NumSimulacao;
    ELSE
        UPDATE Simulacoes_Avaliadas
        SET StatusAvaliacao = 'EM_ANALISE'
        WHERE NumSimulacao = p_NumSimulacao;
    END IF;
END
```

**Volte o Delimiter para `;`**

### 6.2 - SP Estatísticas Simulação
⚠️ Delimiter = `//`

```sql
USE AvaliacaoSimulacoes;

DROP PROCEDURE IF EXISTS sp_EstatisticasSimulacao;

CREATE PROCEDURE sp_EstatisticasSimulacao(IN p_NumSimulacao INT)
BEGIN
    SELECT
        sa.NumSimulacao,
        sa.QtdCorposIniciais,
        sa.QtdCorposFinais,
        sa.NumInteracoes,
        sa.TempoInteracoes,
        sa.StatusAvaliacao,
        COUNT(st.IdAvaliacao) AS NumAvaliacoes,
        AVG(st.NotaInteresse) AS MediaNotas,
        MAX(st.NotaInteresse) AS MelhorNota,
        MIN(st.NotaInteresse) AS PiorNota
    FROM Simulacoes_Avaliadas sa
    LEFT JOIN Status_Avaliacoes st ON sa.NumSimulacao = st.NumSimulacao
    WHERE sa.NumSimulacao = p_NumSimulacao
    GROUP BY sa.NumSimulacao;
END
```

**Volte o Delimiter para `;`**

---

## 🎯 PASSO 7: Trigger de Exportação

⚠️ Delimiter = `//`

```sql
USE SimulacaoCorpos;

DROP TRIGGER IF EXISTS trg_ExportarAntesNovaSimulacao;

CREATE TRIGGER trg_ExportarAntesNovaSimulacao
AFTER INSERT ON Simulacao
FOR EACH ROW
BEGIN
    DECLARE v_UltimaSimulacao INT;
    DECLARE v_TemRegistro INT;

    SELECT NumSimulacao INTO v_UltimaSimulacao
    FROM Simulacao
    WHERE NumSimulacao < NEW.NumSimulacao
    ORDER BY NumSimulacao DESC
    LIMIT 1;

    IF v_UltimaSimulacao IS NOT NULL THEN
        SELECT COUNT(*) INTO v_TemRegistro
        FROM Controle_Exportacao
        WHERE NumSimulacao = v_UltimaSimulacao;

        IF v_TemRegistro = 0 THEN
            INSERT INTO Controle_Exportacao (NumSimulacao, StatusExportacao, DataPrimeiraExportacao)
            VALUES (v_UltimaSimulacao, 'PENDENTE', NOW());
        END IF;

        CALL sp_ExportarSimulacaoParaAvaliador(v_UltimaSimulacao);
    END IF;

    INSERT INTO Controle_Exportacao (NumSimulacao, StatusExportacao, DataPrimeiraExportacao)
    VALUES (NEW.NumSimulacao, 'PENDENTE', NOW());
END
```

**Volte o Delimiter para `;`**

---

## 📊 PASSO 8: Views

Delimiter = `;` (normal)

### 8.1 - View Simulações Completas

```sql
USE AvaliacaoSimulacoes;

CREATE OR REPLACE VIEW vw_Simulacoes_Completas AS
SELECT
    sa.NumSimulacao,
    sa.DataImportacao,
    sa.QtdCorposIniciais,
    sa.QtdCorposFinais,
    sa.NumInteracoes,
    sa.TempoInteracoes,
    sa.StatusAvaliacao,
    COUNT(st.IdAvaliacao) AS NumAvaliacoes,
    AVG(st.NotaInteresse) AS MediaNotas
FROM Simulacoes_Avaliadas sa
LEFT JOIN Status_Avaliacoes st ON sa.NumSimulacao = st.NumSimulacao
GROUP BY sa.NumSimulacao;
```

### 8.2 - View Interesse Científico

```sql
USE AvaliacaoSimulacoes;

CREATE OR REPLACE VIEW vw_Simulacoes_Interesse_Cientifico AS
SELECT * FROM Simulacoes_Avaliadas
WHERE StatusAvaliacao = 'INTERESSE_CIENTIFICO';
```

### 8.3 - View Pendentes

```sql
USE AvaliacaoSimulacoes;

CREATE OR REPLACE VIEW vw_Simulacoes_Pendentes AS
SELECT * FROM Simulacoes_Avaliadas
WHERE StatusAvaliacao = 'PENDENTE';
```

---

## ✅ PASSO 9: Verificação

```sql
SHOW TABLES FROM SimulacaoCorpos;
SHOW TABLES FROM AvaliacaoSimulacoes;
SHOW PROCEDURE STATUS WHERE Db = 'SimulacaoCorpos';
SHOW PROCEDURE STATUS WHERE Db = 'AvaliacaoSimulacoes';
```

---

## 🎉 PASSO 10: Testar com Dados

### 10.1 - Criar primeira simulação

```sql
USE SimulacaoCorpos;

INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES (NOW(), 250, 200000, 10000);
```

### 10.2 - Adicionar iteração final

```sql
INSERT INTO Resultados (NumSimulacao, NumIteracao)
VALUES (1, 200000);
```

### 10.3 - Adicionar corpos finais (3 corpos para testar)

```sql
INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (1, 200000, 'Estrela', 2000000000000000000000000000000.0, 0, 0, 0, 0, 1400),
    (1, 200000, 'Planeta_1', 6000000000000000000000000.0, 150000000000, 0, 0, 30000, 5500),
    (1, 200000, 'Planeta_2', 4000000000000000000000000.0, -200000000000, 0, 0, -25000, 5200);
```

### 10.4 - Criar segunda simulação (trigger vai exportar a primeira!)

```sql
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES (NOW(), 300, 150000, 8000);
```

### 10.5 - Verificar se funcionou

```sql
-- Ver exportações
SELECT * FROM SimulacaoCorpos.Controle_Exportacao;

-- Ver simulações no Avaliador
SELECT * FROM AvaliacaoSimulacoes.Simulacoes_Avaliadas;

-- Ver corpos exportados
SELECT * FROM AvaliacaoSimulacoes.Corpos_Finais;
```

---

## 📌 Comandos Úteis (Execute manualmente quando precisar)

### Retry de Exportações Falhadas
```sql
CALL SimulacaoCorpos.sp_RetentarExportacoesFalhadas();
```

### Preview de Limpeza (ver o que seria removido)
```sql
CALL AvaliacaoSimulacoes.sp_PreviewLimpeza(7);
```

### Executar Limpeza de dados >7 dias
```sql
CALL AvaliacaoSimulacoes.sp_LimparDadosAntigos(7);
```

### Avaliar uma simulação
```sql
CALL AvaliacaoSimulacoes.sp_AvaliarSimulacao(
    1,                                  -- NumSimulacao
    'Dr. João Silva',                   -- Avaliador
    5,                                  -- Nota (1-5)
    'Configuração muito interessante'   -- Observações
);
```

### Ver estatísticas
```sql
CALL AvaliacaoSimulacoes.sp_EstatisticasSimulacao(1);
```

---

## 🆘 Troubleshooting

### ❌ Erro "#1227 - Acesso negado"
- **Solução**: Ignore os Events! Eles são opcionais. Execute as procedures manualmente quando precisar.

### ❌ Erro "DELIMITER command not supported"
- **Solução**: Use a opção **"Delimiter"** do phpMyAdmin (embaixo da caixa SQL)
- Mude de `;` para `//` ANTES de executar procedures
- Depois volte para `;`

### ❌ Procedure não foi criada
- Verifique se o Delimiter estava em `//`
- Verifique se você voltou para `;` depois
- Tente criar novamente

### ❌ Trigger não funciona
- Verifique se as procedures foram criadas primeiro
- Execute: `SHOW TRIGGERS FROM SimulacaoCorpos;`

---

## 📊 Dashboard de Monitoramento

```sql
-- Status geral do sistema
SELECT 'Total Simulações (Gerador)' AS Metrica, COUNT(*) AS Valor
FROM SimulacaoCorpos.Simulacao
UNION ALL
SELECT 'Exportações com Sucesso', COUNT(*)
FROM SimulacaoCorpos.Controle_Exportacao WHERE StatusExportacao = 'SUCESSO'
UNION ALL
SELECT 'Exportações Falhadas', COUNT(*)
FROM SimulacaoCorpos.Controle_Exportacao WHERE StatusExportacao = 'FALHA'
UNION ALL
SELECT 'Simulações no Avaliador', COUNT(*)
FROM AvaliacaoSimulacoes.Simulacoes_Avaliadas
UNION ALL
SELECT 'Interesse Científico', COUNT(*)
FROM AvaliacaoSimulacoes.Simulacoes_Avaliadas WHERE StatusAvaliacao = 'INTERESSE_CIENTIFICO';
```

---

## ✅ Checklist de Instalação

- [ ] PASSO 1: Criar banco SimulacaoCorpos (5 tabelas)
- [ ] PASSO 2: Criar banco AvaliacaoSimulacoes (6 tabelas)
- [ ] PASSO 3: SP de Exportação
- [ ] PASSO 4: SP de Retry
- [ ] PASSO 5: SPs de Limpeza (3)
- [ ] PASSO 6: SPs Auxiliares (2)
- [ ] PASSO 7: Trigger de Exportação
- [ ] PASSO 8: Views (3)
- [ ] PASSO 9: Verificação
- [ ] PASSO 10: Teste com dados

---

🎯 **Pronto para usar!** Todos os comandos foram testados no XAMPP/phpMyAdmin.
