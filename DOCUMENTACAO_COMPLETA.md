# Sistema de Simulações Gravitacionais - Documentação Completa

## Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura do Sistema](#arquitetura-do-sistema)
3. [Modelo Físico - Schema Gerador](#modelo-físico---schema-gerador)
4. [Modelo Físico - Schema Avaliador](#modelo-físico---schema-avaliador)
5. [Fluxo de Dados](#fluxo-de-dados)
6. [Índices e Otimizações](#índices-e-otimizações)
7. [Stored Procedures](#stored-procedures)
8. [Triggers e Events](#triggers-e-events)
9. [Instalação e Configuração](#instalação-e-configuração)
10. [Testes e Validação](#testes-e-validação)
11. [Requisitos Atendidos](#requisitos-atendidos)

---

## Visão Geral

O sistema implementa dois bancos de dados integrados para gerenciar simulações gravitacionais:

- **Gerador de Simulações** (`SimulacaoCorpos`): Armazena todas as iterações das simulações
- **Avaliador de Simulações** (`AvaliacaoSimulacoes`): Armazena apenas os resultados finais para avaliação científica

### Características Principais

- ✅ Exportação automática ao iniciar nova simulação
- ✅ Garantia de atomicidade (transações ACID)
- ✅ Retry automático em caso de falha
- ✅ Filtro: apenas simulações com 3+ corpos finais
- ✅ Limpeza automática de dados antigos (>7 dias)
- ✅ Índices otimizados para grande volume de dados
- ✅ Controle de status de exportação

---

## Arquitetura do Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                    GERADOR DE SIMULAÇÕES                        │
│                   (Schema: SimulacaoCorpos)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐   │
│  │  Simulacao   │────▶│ Resultados   │────▶│    Corpos    │   │
│  └──────────────┘     └──────────────┘     └──────────────┘   │
│                                                                 │
│  ┌────────────────────────────────────┐                        │
│  │    Controle_Exportacao             │                        │
│  │  (controla status de exportação)   │                        │
│  └────────────────────────────────────┘                        │
│                                                                 │
│  ┌────────────────────────────────────┐                        │
│  │  Trigger: Nova Simulação           │                        │
│  │  ➜ Exporta simulação anterior      │                        │
│  └────────────────────────────────────┘                        │
└───────────────────┬─────────────────────────────────────────────┘
                    │
                    │ sp_ExportarSimulacaoParaAvaliador()
                    │ (stored procedure com transação)
                    │
                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                  AVALIADOR DE SIMULAÇÕES                        │
│                (Schema: AvaliacaoSimulacoes)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────┐     ┌─────────────────┐               │
│  │ Simulacoes_        │────▶│ Resultados_     │               │
│  │ Avaliadas          │     │ Finais          │               │
│  └────────────────────┘     └─────────────────┘               │
│           │                          │                         │
│           │                          ▼                         │
│           │                  ┌─────────────────┐              │
│           │                  │ Corpos_Finais   │              │
│           │                  └─────────────────┘              │
│           │                                                    │
│           ├──────────────▶ ┌───────────────────────┐          │
│           │                │ Status_Avaliacoes     │          │
│           │                └───────────────────────┘          │
│           │                                                    │
│           └──────────────▶ ┌───────────────────────┐          │
│                            │ Historico_Exportacoes │          │
│                            └───────────────────────┘          │
│                                                                 │
│  ┌────────────────────────────────────┐                        │
│  │  Event: Limpeza Automática         │                        │
│  │  ➜ Remove dados >7 dias (diária)   │                        │
│  └────────────────────────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Modelo Físico - Schema Gerador

### 1. Tabela: Simulacao

| Campo            | Tipo         | Restrições           | Descrição                              |
|------------------|--------------|----------------------|----------------------------------------|
| NumSimulacao     | INT          | PK, AUTO_INCREMENT   | Identificador único da simulação       |
| DataSimulacao    | VARCHAR(50)  | NOT NULL             | Data/hora da simulação                 |
| QtdCorposInicial | INT          | NOT NULL, > 0        | Quantidade inicial de corpos           |
| NumInteracoes    | INT          | NOT NULL, > 0        | Número de iterações planejadas         |
| TempoInteracoes  | INT          | NOT NULL, > 0        | Tempo total de interações (segundos)   |

**Índices:**
- PK: `NumSimulacao`

### 2. Tabela: Resultados

| Campo         | Tipo | Restrições              | Descrição                           |
|---------------|------|-------------------------|-------------------------------------|
| NumSimulacao  | INT  | PK, FK → Simulacao      | Referência à simulação              |
| NumIteracao   | INT  | PK                      | Número da iteração (0, 1, 2, ...)   |

**Chave Primária Composta:** `(NumSimulacao, NumIteracao)`

**Índices:**
- `idx_resultados_iteracao`: NumIteracao
- `idx_resultados_sim_iter`: (NumSimulacao, NumIteracao DESC) - **para exportação**

### 3. Tabela: Corpos

| Campo          | Tipo         | Restrições                   | Descrição                          |
|----------------|--------------|------------------------------|------------------------------------|
| IdCorpo        | INT          | PK, AUTO_INCREMENT           | Identificador único do corpo       |
| NumSimulacao   | INT          | FK → Resultados              | Referência à simulação             |
| NumIteracao    | INT          | FK → Resultados              | Referência à iteração              |
| NomeCorpo      | VARCHAR(100) | NOT NULL                     | Nome do corpo                      |
| MassaCorpo     | FLOAT        | NOT NULL, > 0                | Massa do corpo (kg)                |
| PosX           | FLOAT        | NOT NULL                     | Posição X (metros)                 |
| PosY           | FLOAT        | NOT NULL                     | Posição Y (metros)                 |
| VelX           | FLOAT        | NOT NULL                     | Velocidade X (m/s)                 |
| VelY           | FLOAT        | NOT NULL                     | Velocidade Y (m/s)                 |
| DensidadeCorpo | FLOAT        | NOT NULL, > 0                | Densidade (kg/m³)                  |

**Índices:**
- `idx_corpos_nome`: NomeCorpo
- `idx_corpos_exportacao`: (NumSimulacao, NumIteracao) - **para exportação**

### 4. Tabela: Controle_Exportacao (Nova)

| Campo               | Tipo         | Restrições              | Descrição                           |
|---------------------|--------------|-------------------------|-------------------------------------|
| NumSimulacao        | INT          | PK, FK → Simulacao      | Referência à simulação              |
| DataUltimaTentativa | DATETIME     |                         | Data da última tentativa            |
| StatusExportacao    | ENUM         | DEFAULT 'PENDENTE'      | PENDENTE, SUCESSO, FALHA            |
| NumTentativas       | INT          | DEFAULT 0               | Contador de tentativas              |
| MensagemErro        | TEXT         |                         | Mensagem de erro se falhou          |
| QtdCorposFinais     | INT          |                         | Quantidade de corpos finais         |

**Índices:**
- `idx_controle_status`: StatusExportacao
- `idx_controle_data`: DataUltimaTentativa

### Diagrama ER - Gerador

```
┌───────────────────────┐
│     Simulacao         │
├───────────────────────┤
│ PK NumSimulacao       │
│    DataSimulacao      │
│    QtdCorposInicial   │
│    NumInteracoes      │
│    TempoInteracoes    │
└───────────┬───────────┘
            │ 1
            │
            │ N
┌───────────▼───────────┐         ┌──────────────────────┐
│    Resultados         │         │ Controle_Exportacao  │
├───────────────────────┤         ├──────────────────────┤
│ PK,FK NumSimulacao    │         │ PK,FK NumSimulacao   │
│ PK    NumIteracao     │◄────┐   │    DataUltimaTent.   │
└───────────┬───────────┘     │   │    StatusExportacao  │
            │ 1               │   │    NumTentativas     │
            │                 │   │    MensagemErro      │
            │ N               │   │    QtdCorposFinais   │
┌───────────▼───────────┐     │   └──────────────────────┘
│       Corpos          │     │
├───────────────────────┤     │
│ PK IdCorpo            │     │
│ FK NumSimulacao       ├─────┘
│ FK NumIteracao        │
│    NomeCorpo          │
│    MassaCorpo         │
│    PosX, PosY         │
│    VelX, VelY         │
│    DensidadeCorpo     │
└───────────────────────┘
```

---

## Modelo Físico - Schema Avaliador

### 1. Tabela: Simulacoes_Avaliadas

| Campo            | Tipo         | Restrições                    | Descrição                              |
|------------------|--------------|-------------------------------|----------------------------------------|
| NumSimulacao     | INT          | PK                            | Mesmo ID do gerador                    |
| DataSimulacao    | DATETIME     | NOT NULL                      | Data/hora da simulação                 |
| DataImportacao   | DATETIME     | NOT NULL, DEFAULT NOW()       | Data de importação                     |
| QtdCorposInicial | INT          | NOT NULL, >= 200              | Quantidade inicial de corpos           |
| QtdCorposFinais  | INT          | NOT NULL, >= 3                | Quantidade final (filtro)              |
| NumInteracoes    | INT          | NOT NULL, 100k-500k           | Número de iterações                    |
| TempoInteracoes  | INT          | NOT NULL, > 0                 | Tempo total (segundos)                 |
| StatusAvaliacao  | ENUM         | DEFAULT 'PENDENTE'            | Status da avaliação científica         |

**Valores StatusAvaliacao:**
- `PENDENTE`: Aguardando avaliação
- `EM_ANALISE`: Em análise
- `INTERESSE_CIENTIFICO`: Tem interesse científico
- `SEM_INTERESSE`: Sem interesse científico

**Índices:**
- `idx_simulacoes_data_importacao`: DataImportacao
- `idx_simulacoes_status`: StatusAvaliacao
- `idx_simulacoes_qtd_corpos`: QtdCorposFinais

### 2. Tabela: Resultados_Finais

| Campo          | Tipo | Restrições                        | Descrição                      |
|----------------|------|-----------------------------------|--------------------------------|
| NumSimulacao   | INT  | PK, FK → Simulacoes_Avaliadas     | Referência à simulação         |
| NumIteracao    | INT  | NOT NULL                          | Última iteração executada      |
| TempoExecucao  | INT  | NOT NULL                          | Tempo total de execução        |

### 3. Tabela: Corpos_Finais

| Campo          | Tipo         | Restrições                   | Descrição                          |
|----------------|--------------|------------------------------|------------------------------------|
| IdCorpo        | INT          | PK, AUTO_INCREMENT           | Identificador único do corpo       |
| NumSimulacao   | INT          | FK → Resultados_Finais       | Referência à simulação             |
| NomeCorpo      | VARCHAR(100) | NOT NULL                     | Nome do corpo                      |
| MassaCorpo     | FLOAT        | NOT NULL, > 0                | Massa do corpo (kg)                |
| PosX           | FLOAT        | NOT NULL                     | Posição X (metros)                 |
| PosY           | FLOAT        | NOT NULL                     | Posição Y (metros)                 |
| VelX           | FLOAT        | NOT NULL                     | Velocidade X (m/s)                 |
| VelY           | FLOAT        | NOT NULL                     | Velocidade Y (m/s)                 |
| DensidadeCorpo | FLOAT        | NOT NULL, > 0                | Densidade (kg/m³)                  |
| EnergiaTotal   | FLOAT        |                              | Energia cinética calculada         |
| MomentoAngular | FLOAT        |                              | Momento angular calculado          |

**Cálculos Automáticos:**
- `EnergiaTotal = 0.5 * MassaCorpo * (VelX² + VelY²)`
- `MomentoAngular = MassaCorpo * (PosX * VelY - PosY * VelX)`

**Índices:**
- `idx_corpos_finais_simulacao`: NumSimulacao
- `idx_corpos_finais_nome`: NomeCorpo
- `idx_corpos_finais_massa`: MassaCorpo

### 4. Tabela: Historico_Exportacoes

| Campo              | Tipo     | Restrições                        | Descrição                      |
|--------------------|----------|-----------------------------------|--------------------------------|
| IdExportacao       | INT      | PK, AUTO_INCREMENT                | ID da exportação               |
| NumSimulacao       | INT      | FK → Simulacoes_Avaliadas         | Simulação exportada            |
| DataTentativa      | DATETIME | NOT NULL, DEFAULT NOW()           | Data da tentativa              |
| StatusExportacao   | ENUM     | NOT NULL                          | SUCESSO, FALHA, PARCIAL        |
| MensagemErro       | TEXT     |                                   | Mensagem de erro se falhou     |
| QtdCorposExportados| INT      | DEFAULT 0                         | Quantidade exportada           |

**Índices:**
- `idx_historico_status`: StatusExportacao
- `idx_historico_data`: DataTentativa

### 5. Tabela: Status_Avaliacoes

| Campo          | Tipo         | Restrições                   | Descrição                          |
|----------------|--------------|------------------------------|------------------------------------|
| IdAvaliacao    | INT          | PK, AUTO_INCREMENT           | ID da avaliação                    |
| NumSimulacao   | INT          | FK → Simulacoes_Avaliadas    | Simulação avaliada                 |
| DataAvaliacao  | DATETIME     | NOT NULL, DEFAULT NOW()      | Data da avaliação                  |
| Avaliador      | VARCHAR(100) | NOT NULL                     | Nome do avaliador                  |
| NotaInteresse  | INT          | NOT NULL, 1-5                | Nota de interesse científico       |
| Observacoes    | TEXT         |                              | Observações do avaliador           |

**Índices:**
- `idx_avaliacoes_nota`: NotaInteresse
- `idx_avaliacoes_data`: DataAvaliacao

### 6. Tabela: Log_Limpeza

| Campo                  | Tipo     | Restrições              | Descrição                           |
|------------------------|----------|-------------------------|-------------------------------------|
| IdLog                  | INT      | PK, AUTO_INCREMENT      | ID do log                           |
| DataLimpeza            | DATETIME | NOT NULL, DEFAULT NOW() | Data da limpeza                     |
| QtdSimulacoesRemovidas | INT      | DEFAULT 0               | Quantidade removida                 |
| QtdCorposRemovidos     | INT      | DEFAULT 0               | Corpos removidos                    |
| QtdAvaliacoesRemovidas | INT      | DEFAULT 0               | Avaliações removidas                |
| DataLimiteRemocao      | DATETIME |                         | Data limite usada                   |
| TempoExecucao          | INT      |                         | Tempo em segundos                   |
| Observacoes            | TEXT     |                         | Observações sobre a limpeza         |

### Diagrama ER - Avaliador

```
┌─────────────────────────┐
│  Simulacoes_Avaliadas   │
├─────────────────────────┤
│ PK NumSimulacao         │
│    DataSimulacao        │
│    DataImportacao       │
│    QtdCorposInicial     │
│    QtdCorposFinais      │
│    NumInteracoes        │
│    TempoInteracoes      │
│    StatusAvaliacao      │
└────────┬────────────────┘
         │ 1
         ├────────┬────────┬────────┐
         │        │        │        │
         │ 1      │ N      │ N      │ N
         │        │        │        │
┌────────▼─────┐  │  ┌─────▼──────┐ │  ┌───────▼─────────┐
│ Resultados_  │  │  │ Historico_ │ │  │ Status_         │
│ Finais       │  │  │ Exportacoes│ │  │ Avaliacoes      │
├──────────────┤  │  ├────────────┤ │  ├─────────────────┤
│PK,FK NumSim. │  │  │PK IdExport.│ │  │PK IdAvaliacao   │
│    NumIter.  │  │  │FK NumSim.  │ │  │FK NumSimulacao  │
│    TempoExec.│  │  │  DataTent. │ │  │  DataAvaliacao  │
└──────┬───────┘  │  │  Status    │ │  │  Avaliador      │
       │ 1        │  │  MsgErro   │ │  │  NotaInteresse  │
       │          │  │  QtdCorpos │ │  │  Observacoes    │
       │ N        │  └────────────┘ │  └─────────────────┘
┌──────▼───────┐  │                 │
│ Corpos_      │  │                 │
│ Finais       │  │                 │
├──────────────┤  │                 │
│PK IdCorpo    │  │                 │
│FK NumSim.    │  │                 │
│  NomeCorpo   │  │                 │
│  MassaCorpo  │  │                 │
│  Pos X,Y     │  │                 │
│  Vel X,Y     │  │                 │
│  Densidade   │  │                 │
│  Energia     │  │                 │
│  Momento     │  │                 │
└──────────────┘  │                 │
                  │                 │
         ┌────────▼────────┐        │
         │ Log_Limpeza     │        │
         ├─────────────────┤        │
         │ PK IdLog        │        │
         │    DataLimpeza  │        │
         │    QtdSimulac.  │        │
         │    QtdCorpos    │        │
         │    QtdAvaliacs. │        │
         │    DataLimite   │        │
         │    TempoExec.   │        │
         │    Observacoes  │        │
         └─────────────────┘        │
```

---

## Fluxo de Dados

### 1. Fluxo de Exportação

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUXO DE EXPORTAÇÃO                          │
└─────────────────────────────────────────────────────────────────┘

1. TRIGGER: Nova simulação inserida
   ↓
2. Identificar simulação anterior
   ↓
3. Verificar se já foi exportada (Controle_Exportacao)
   ↓
   ├─ SIM (SUCESSO) → Sair
   │
   └─ NÃO ou FALHA → Continuar
      ↓
4. sp_ExportarSimulacaoParaAvaliador(NumSimulacao)
   ↓
5. Verificar quantidade de corpos finais
   ↓
   ├─ < 3 corpos → Não exportar, registrar em Controle_Exportacao
   │
   └─ >= 3 corpos → Continuar exportação
      ↓
6. START TRANSACTION
   ↓
7. Inserir em Simulacoes_Avaliadas
   ↓
8. Inserir em Resultados_Finais
   ↓
9. Inserir em Corpos_Finais (com cálculos)
   ↓
10. Inserir em Historico_Exportacoes
    ↓
11. COMMIT
    ↓
12. Atualizar Controle_Exportacao (SUCESSO)

    [SE ERRO EM QUALQUER PASSO]
    ↓
    ROLLBACK
    ↓
    Atualizar Controle_Exportacao (FALHA)
    ↓
    Event: Retry após 1 hora
```

### 2. Fluxo de Limpeza

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUXO DE LIMPEZA                             │
└─────────────────────────────────────────────────────────────────┘

1. EVENT: Execução diária à meia-noite
   ↓
2. sp_LimparDadosAntigos(7 dias)
   ↓
3. Calcular data limite (NOW() - 7 dias)
   ↓
4. Contar registros a remover
   ↓
   ├─ Nenhum → Registrar em Log_Limpeza, Sair
   │
   └─ Existem registros → Continuar
      ↓
5. START TRANSACTION
   ↓
6. DELETE Status_Avaliacoes (para simulações antigas)
   ↓
7. DELETE Historico_Exportacoes
   ↓
8. DELETE Corpos_Finais
   ↓
9. DELETE Resultados_Finais
   ↓
10. DELETE Simulacoes_Avaliadas
    ↓
11. COMMIT
    ↓
12. OPTIMIZE TABLES
    ↓
13. Registrar em Log_Limpeza
```

---

## Índices e Otimizações

### Justificativa dos Índices

Considerando:
- **50 simulações/dia**
- **200-1000 corpos por simulação**
- **100.000-500.000 iterações por simulação**

#### Cálculo de Volume de Dados:

**Por simulação:**
- Iterações: ~300.000 (média)
- Corpos por iteração: ~500 (média considerando colisões)
- Total de registros em Corpos: 150.000.000 (150 milhões)

**Anual:**
- Simulações: 50 * 365 = 18.250
- Registros em Corpos: 2.737.500.000.000 (2,7 trilhões)

### Índices Críticos para Exportação

#### 1. Schema Gerador

```sql
-- Índice composto para buscar última iteração rapidamente
CREATE INDEX idx_resultados_sim_iter
ON Resultados(NumSimulacao, NumIteracao DESC);

-- Índice para buscar corpos de uma iteração específica
CREATE INDEX idx_corpos_exportacao
ON Corpos(NumSimulacao, NumIteracao);

-- Índice para controle de exportação
CREATE INDEX idx_controle_status
ON Controle_Exportacao(StatusExportacao);
```

**Justificativa:**
- `idx_resultados_sim_iter`: Permite encontrar a última iteração em O(1) ao invés de O(n)
- `idx_corpos_exportacao`: Facilita a busca de todos os corpos da última iteração
- `idx_controle_status`: Otimiza retry de exportações falhadas

#### 2. Schema Avaliador

```sql
-- Índice para filtrar por data de importação (limpeza)
CREATE INDEX idx_simulacoes_data_importacao
ON Simulacoes_Avaliadas(DataImportacao);

-- Índice para filtrar por status de avaliação
CREATE INDEX idx_simulacoes_status
ON Simulacoes_Avaliadas(StatusAvaliacao);

-- Índice para buscar corpos de uma simulação
CREATE INDEX idx_corpos_finais_simulacao
ON Corpos_Finais(NumSimulacao);
```

**Justificativa:**
- `idx_simulacoes_data_importacao`: Essencial para a limpeza diária (WHERE DataImportacao < DATE_SUB(...))
- `idx_simulacoes_status`: Facilita consultas de simulações pendentes
- `idx_corpos_finais_simulacao`: FK index para joins frequentes

### Análise de Performance

```sql
-- Sem índice:
-- SELECT MAX(NumIteracao) FROM Resultados WHERE NumSimulacao = X
-- Custo: O(n) onde n = número de iterações (~300.000)

-- Com índice idx_resultados_sim_iter:
-- Custo: O(1) - acesso direto ao primeiro registro ordenado DESC
```

---

## Stored Procedures

### 1. sp_ExportarSimulacaoParaAvaliador

**Localização:** `SimulacaoCorpos`

**Parâmetros:**
- `IN p_NumSimulacao INT`

**Funcionalidade:**
- Exporta uma simulação completa do Gerador para o Avaliador
- Verifica se a simulação tem 3+ corpos finais
- Usa transações para garantir atomicidade
- Calcula energia e momento angular automaticamente
- Registra status em Controle_Exportacao

**Exemplo:**
```sql
CALL SimulacaoCorpos.sp_ExportarSimulacaoParaAvaliador(5);
```

### 2. sp_RetentarExportacoesFalhadas

**Localização:** `SimulacaoCorpos`

**Funcionalidade:**
- Percorre todas as simulações com status FALHA
- Tenta reexportar cada uma
- Executada automaticamente a cada 1 hora via Event

**Exemplo:**
```sql
CALL SimulacaoCorpos.sp_RetentarExportacoesFalhadas();
```

### 3. sp_LimparDadosAntigos

**Localização:** `AvaliacaoSimulacoes`

**Parâmetros:**
- `IN p_DiasRetencao INT`

**Funcionalidade:**
- Remove simulações mais antigas que X dias
- Usa transações para garantir atomicidade
- Otimiza tabelas após remoção
- Registra estatísticas em Log_Limpeza

**Exemplo:**
```sql
-- Remover simulações com mais de 7 dias
CALL AvaliacaoSimulacoes.sp_LimparDadosAntigos(7);

-- Remover simulações com mais de 30 dias
CALL AvaliacaoSimulacoes.sp_LimparDadosAntigos(30);
```

### 4. sp_PreviewLimpeza

**Localização:** `AvaliacaoSimulacoes`

**Parâmetros:**
- `IN p_DiasRetencao INT`

**Funcionalidade:**
- Mostra o que seria removido SEM remover
- Útil para verificar antes de executar limpeza

**Exemplo:**
```sql
-- Ver o que seria removido com 7 dias
CALL AvaliacaoSimulacoes.sp_PreviewLimpeza(7);
```

### 5. sp_AvaliarSimulacao

**Localização:** `AvaliacaoSimulacoes`

**Parâmetros:**
- `IN p_NumSimulacao INT`
- `IN p_Avaliador VARCHAR(100)`
- `IN p_NotaInteresse INT` (1-5)
- `IN p_Observacoes TEXT`

**Funcionalidade:**
- Registra avaliação científica de uma simulação
- Atualiza StatusAvaliacao automaticamente baseado na nota
- Nota >= 4: INTERESSE_CIENTIFICO
- Nota 2-3: EM_ANALISE
- Nota 1: SEM_INTERESSE

**Exemplo:**
```sql
CALL AvaliacaoSimulacoes.sp_AvaliarSimulacao(
    5,
    'Dr. João Silva',
    4,
    'Sistema estável com configuração rara de 8 corpos'
);
```

### 6. sp_EstatisticasSimulacao

**Localização:** `AvaliacaoSimulacoes`

**Parâmetros:**
- `IN p_NumSimulacao INT`

**Funcionalidade:**
- Retorna estatísticas completas de uma simulação
- Massa total, média, quantidade de avaliações, etc.

**Exemplo:**
```sql
CALL AvaliacaoSimulacoes.sp_EstatisticasSimulacao(5);
```

### 7. sp_HistoricoLimpeza

**Localização:** `AvaliacaoSimulacoes`

**Parâmetros:**
- `IN p_Limite INT` (padrão: 30)

**Funcionalidade:**
- Mostra histórico das últimas limpezas executadas

**Exemplo:**
```sql
CALL AvaliacaoSimulacoes.sp_HistoricoLimpeza(10);
```

---

## Triggers e Events

### Triggers

#### 1. trg_ExportarAntesNovaSimulacao

**Tabela:** `SimulacaoCorpos.Simulacao`
**Evento:** `AFTER INSERT`
**Funcionalidade:**
- Quando uma nova simulação é inserida
- Identifica a simulação anterior
- Verifica se já foi exportada
- Se não, chama sp_ExportarSimulacaoParaAvaliador

```sql
-- Exemplo de disparo:
INSERT INTO SimulacaoCorpos.Simulacao
(DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES (NOW(), 250, 200000, 10000);
-- Trigger automaticamente exporta a simulação anterior
```

### Events (Agendados)

#### 1. evt_RetryExportacoesFalhadas

**Schema:** `SimulacaoCorpos`
**Frequência:** A cada 1 hora
**Funcionalidade:**
- Tenta reexportar simulações que falharam

```sql
-- Ver status do evento:
SELECT * FROM information_schema.EVENTS
WHERE EVENT_NAME = 'evt_RetryExportacoesFalhadas';

-- Desabilitar temporariamente:
ALTER EVENT evt_RetryExportacoesFalhadas DISABLE;

-- Reabilitar:
ALTER EVENT evt_RetryExportacoesFalhadas ENABLE;
```

#### 2. evt_LimpezaAutomatica

**Schema:** `AvaliacaoSimulacoes`
**Frequência:** Diária (meia-noite)
**Funcionalidade:**
- Remove simulações com mais de 7 dias
- Otimiza tabelas
- Registra log

```sql
-- Ver status do evento:
SELECT * FROM information_schema.EVENTS
WHERE EVENT_NAME = 'evt_LimpezaAutomatica';

-- Executar manualmente (não esperar meia-noite):
CALL AvaliacaoSimulacoes.sp_LimparDadosAntigos(7);
```

### Ativar Event Scheduler

```sql
-- Verificar se está ativo:
SHOW VARIABLES LIKE 'event_scheduler';

-- Ativar:
SET GLOBAL event_scheduler = ON;

-- Adicionar ao my.cnf para persistir após restart:
[mysqld]
event_scheduler=ON
```

---

## Instalação e Configuração

### Pré-requisitos

- MySQL 5.7+ ou MariaDB 10.2+
- Privilégios de CREATE DATABASE
- Privilégios de CREATE EVENT (para event scheduler)

### Instalação Completa

#### Opção 1: Setup Automatizado

```bash
# Entrar no MySQL
mysql -u root -p

# Executar setup completo
SOURCE setup_completo.sql;
```

Este script executa na ordem:
1. `mysql_database_setup.sql` (Gerador)
2. `schema_avaliador.sql` (Avaliador)
3. `integracao_gerador_avaliador.sql` (Integração)
4. `rotina_limpeza.sql` (Limpeza)

#### Opção 2: Instalação Manual

```bash
mysql -u root -p < mysql_database_setup.sql
mysql -u root -p < schema_avaliador.sql
mysql -u root -p < integracao_gerador_avaliador.sql
mysql -u root -p < rotina_limpeza.sql
```

### Carregar Dados de Teste

```bash
mysql -u root -p < dados_teste.sql
```

### Verificação da Instalação

```sql
-- Ver schemas criados
SHOW DATABASES;

-- Ver tabelas do Gerador
USE SimulacaoCorpos;
SHOW TABLES;

-- Ver tabelas do Avaliador
USE AvaliacaoSimulacoes;
SHOW TABLES;

-- Ver stored procedures
SHOW PROCEDURE STATUS WHERE Db IN ('SimulacaoCorpos', 'AvaliacaoSimulacoes');

-- Ver triggers
SHOW TRIGGERS FROM SimulacaoCorpos;

-- Ver events
SHOW EVENTS FROM SimulacaoCorpos;
SHOW EVENTS FROM AvaliacaoSimulacoes;

-- Verificar event scheduler
SHOW VARIABLES LIKE 'event_scheduler';
```

### Configuração de Produção

#### 1. Ajustar Retenção de Dados

Padrão: 7 dias. Para alterar:

```sql
-- Alterar event de limpeza para 14 dias
USE AvaliacaoSimulacoes;
DROP EVENT evt_LimpezaAutomatica;

CREATE EVENT evt_LimpezaAutomatica
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
DO
    CALL sp_LimparDadosAntigos(14);  -- 14 dias ao invés de 7
```

#### 2. Ajustar Frequência de Retry

Padrão: 1 hora. Para alterar:

```sql
-- Alterar retry para 30 minutos
USE SimulacaoCorpos;
DROP EVENT evt_RetryExportacoesFalhadas;

CREATE EVENT evt_RetryExportacoesFalhadas
ON SCHEDULE EVERY 30 MINUTE  -- 30 minutos
DO
    CALL sp_RetentarExportacoesFalhadas();
```

#### 3. Monitoramento

```sql
-- Verificar status de exportações
SELECT
    StatusExportacao,
    COUNT(*) AS Quantidade
FROM SimulacaoCorpos.Controle_Exportacao
GROUP BY StatusExportacao;

-- Verificar tamanho dos bancos
SELECT
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.TABLES
WHERE table_schema IN ('SimulacaoCorpos', 'AvaliacaoSimulacoes')
GROUP BY table_schema;

-- Verificar últimas limpezas
SELECT * FROM AvaliacaoSimulacoes.Log_Limpeza
ORDER BY DataLimpeza DESC
LIMIT 5;
```

---

## Testes e Validação

### 1. Teste de Exportação Automática

```sql
USE SimulacaoCorpos;

-- 1. Criar simulação de teste
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES (NOW(), 250, 200000, 10000);

SET @sim_teste = LAST_INSERT_ID();

-- 2. Adicionar iteração final com 4 corpos
INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim_teste, 200000);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim_teste, 200000, 'Corpo_1', 1e30, 0, 0, 100, 50, 1000),
    (@sim_teste, 200000, 'Corpo_2', 2e24, 1e11, 0, 0, 30000, 5000),
    (@sim_teste, 200000, 'Corpo_3', 3e24, -1e11, 0, 0, -25000, 4500),
    (@sim_teste, 200000, 'Corpo_4', 1e24, 0, 1.5e11, 20000, 0, 4000);

-- 3. Criar nova simulação (dispara trigger que exporta a anterior)
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES (NOW(), 200, 150000, 8000);

-- 4. Verificar exportação
SELECT * FROM Controle_Exportacao WHERE NumSimulacao = @sim_teste;

-- 5. Verificar no avaliador
SELECT * FROM AvaliacaoSimulacoes.Simulacoes_Avaliadas WHERE NumSimulacao = @sim_teste;
SELECT * FROM AvaliacaoSimulacoes.Corpos_Finais WHERE NumSimulacao = @sim_teste;
```

### 2. Teste de Filtro (< 3 corpos)

```sql
USE SimulacaoCorpos;

-- 1. Criar simulação com apenas 2 corpos finais
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES (NOW(), 200, 150000, 7200);

SET @sim_2corpos = LAST_INSERT_ID();

-- 2. Adicionar iteração final com 2 corpos
INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim_2corpos, 150000);

INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim_2corpos, 150000, 'Corpo_A', 1e30, 0, 0, 100, 50, 1000),
    (@sim_2corpos, 150000, 'Corpo_B', 2e24, 1e11, 0, 0, 30000, 5000);

-- 3. Tentar exportar manualmente
CALL sp_ExportarSimulacaoParaAvaliador(@sim_2corpos);

-- 4. Verificar que NÃO foi exportada
SELECT * FROM Controle_Exportacao WHERE NumSimulacao = @sim_2corpos;
-- Deve mostrar: StatusExportacao = 'SUCESSO', MensagemErro = 'menos de 3 corpos finais'

-- 5. Verificar que NÃO está no avaliador
SELECT * FROM AvaliacaoSimulacoes.Simulacoes_Avaliadas WHERE NumSimulacao = @sim_2corpos;
-- Deve retornar 0 linhas
```

### 3. Teste de Retry

```sql
USE SimulacaoCorpos;

-- 1. Simular falha: marcar simulação como FALHA
UPDATE Controle_Exportacao
SET StatusExportacao = 'FALHA',
    MensagemErro = 'Erro simulado para teste'
WHERE NumSimulacao = 2;

-- 2. Executar retry manualmente
CALL sp_RetentarExportacoesFalhadas();

-- 3. Verificar que foi reexportada
SELECT * FROM Controle_Exportacao WHERE NumSimulacao = 2;
-- StatusExportacao deve ser 'SUCESSO'
```

### 4. Teste de Limpeza

```sql
USE AvaliacaoSimulacoes;

-- 1. Preview da limpeza (sem remover)
CALL sp_PreviewLimpeza(7);

-- 2. Executar limpeza de teste (dados > 30 dias)
CALL sp_LimparDadosAntigos(30);

-- 3. Ver log de limpeza
SELECT * FROM Log_Limpeza ORDER BY DataLimpeza DESC LIMIT 1;

-- 4. Verificar dados removidos
SELECT COUNT(*) FROM Simulacoes_Avaliadas;
```

### 5. Teste de Atomicidade (Transação)

```sql
-- Testar rollback em caso de erro

USE SimulacaoCorpos;

-- 1. Desabilitar temporariamente a FK no avaliador (para simular erro)
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE AvaliacaoSimulacoes.Resultados_Finais;

-- 2. Tentar exportar (deve falhar e fazer rollback)
CALL sp_ExportarSimulacaoParaAvaliador(5);

-- 3. Verificar que status é FALHA
SELECT * FROM Controle_Exportacao WHERE NumSimulacao = 5;

-- 4. Restaurar tabela
SET FOREIGN_KEY_CHECKS = 1;
SOURCE schema_avaliador.sql;

-- 5. Tentar novamente (agora deve funcionar)
CALL sp_ExportarSimulacaoParaAvaliador(5);
```

### 6. Teste de Performance

```sql
-- Verificar plano de execução da exportação

USE SimulacaoCorpos;

-- Testar busca da última iteração
EXPLAIN SELECT MAX(NumIteracao)
FROM Resultados
WHERE NumSimulacao = 1;
-- Deve usar índice idx_resultados_sim_iter

-- Testar busca de corpos da última iteração
EXPLAIN SELECT *
FROM Corpos
WHERE NumSimulacao = 1 AND NumIteracao = 100;
-- Deve usar índice idx_corpos_exportacao

-- Testar busca de simulações antigas
USE AvaliacaoSimulacoes;

EXPLAIN SELECT *
FROM Simulacoes_Avaliadas
WHERE DataImportacao < DATE_SUB(NOW(), INTERVAL 7 DAY);
-- Deve usar índice idx_simulacoes_data_importacao
```

---

## Requisitos Atendidos

### ✅ Requisitos Funcionais

| Requisito | Status | Implementação |
|-----------|--------|---------------|
| Dois schemas distintos integrados | ✅ | `SimulacaoCorpos` e `AvaliacaoSimulacoes` |
| Schema do Gerador = exercício N1 | ✅ | `mysql_database_setup.sql` |
| Stored Procedure de exportação | ✅ | `sp_ExportarSimulacaoParaAvaliador()` |
| Exportação automática no início de nova simulação | ✅ | `trg_ExportarAntesNovaSimulacao` |
| Garantia de atomicidade (tudo ou nada) | ✅ | Transações SQL (START TRANSACTION...COMMIT/ROLLBACK) |
| Retry em caso de falha | ✅ | `sp_RetentarExportacoesFalhadas()` + Event |
| Filtro: apenas simulações com 3+ corpos | ✅ | Verificação em `sp_ExportarSimulacaoParaAvaliador()` |
| Limpeza de dados > 1 semana | ✅ | `sp_LimparDadosAntigos(7)` + Event diário |
| Controle de exportações | ✅ | Tabela `Controle_Exportacao` |
| Índices para otimização | ✅ | 12 índices criados |
| Schema do Avaliador projetado pelo grupo | ✅ | `schema_avaliador.sql` |

### ✅ Requisitos de Volume

| Requisito | Valor Esperado | Suportado | Evidência |
|-----------|----------------|-----------|-----------|
| Simulações por dia | ~50 | ✅ Sim | Controle de exportação escalável |
| Corpos por simulação | >= 200 | ✅ Sim | CHECK constraint `QtdCorposInicial >= 200` |
| Iterações por simulação | 100k - 500k | ✅ Sim | CHECK constraint `NumInteracoes BETWEEN 100000 AND 500000` |
| Volume estimado/ano | 2,7 trilhões registros | ✅ Sim | Índices otimizados, limpeza automática |

### ✅ Requisitos de Performance

| Requisito | Implementação |
|-----------|---------------|
| Exportação otimizada | Índice composto `idx_resultados_sim_iter` |
| Busca de corpos rápida | Índice `idx_corpos_exportacao` |
| Limpeza eficiente | Índice `idx_simulacoes_data_importacao` |
| CASCADE deletes | FKs com ON DELETE CASCADE |

### ✅ Requisitos de Confiabilidade

| Requisito | Implementação |
|-----------|---------------|
| Atomicidade | Transações SQL |
| Durabilidade | InnoDB engine |
| Consistência | FKs e CHECK constraints |
| Recuperação de falhas | Retry automático via Event |

### ✅ Entregáveis

| Entregável | Status | Arquivo |
|------------|--------|---------|
| Modelo físico do Gerador | ✅ | Esta documentação, seção "Modelo Físico - Schema Gerador" |
| Modelo físico do Avaliador | ✅ | Esta documentação, seção "Modelo Físico - Schema Avaliador" |
| Scripts SQL | ✅ | `mysql_database_setup.sql`, `schema_avaliador.sql`, etc. |
| Stored Procedures | ✅ | `integracao_gerador_avaliador.sql`, `rotina_limpeza.sql` |
| Implementação MySQL | ✅ | Todos os scripts `.sql` |
| Documentação completa | ✅ | Este arquivo |

---

## Estrutura de Arquivos

```
bd2/
├── mysql_database_setup.sql          # Schema do Gerador (exercício N1)
├── schema_avaliador.sql              # Schema do Avaliador
├── integracao_gerador_avaliador.sql  # Integração e exportação
├── rotina_limpeza.sql                # Rotina de limpeza automática
├── setup_completo.sql                # Setup automatizado
├── dados_teste.sql                   # Dados de teste
├── README_DATABASE.md                # Documentação do Gerador
└── DOCUMENTACAO_COMPLETA.md          # Esta documentação

Total: 7 arquivos SQL + 2 documentações
```

---

## Consultas Úteis de Monitoramento

### Monitoramento do Gerador

```sql
USE SimulacaoCorpos;

-- Status geral de exportações
SELECT
    StatusExportacao,
    COUNT(*) AS Quantidade,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Controle_Exportacao), 2) AS Percentual
FROM Controle_Exportacao
GROUP BY StatusExportacao;

-- Simulações pendentes de exportação
SELECT
    s.NumSimulacao,
    s.DataSimulacao,
    s.QtdCorposInicial,
    ce.StatusExportacao,
    ce.NumTentativas
FROM Simulacao s
LEFT JOIN Controle_Exportacao ce ON s.NumSimulacao = ce.NumSimulacao
WHERE ce.StatusExportacao IS NULL OR ce.StatusExportacao = 'PENDENTE'
ORDER BY s.DataSimulacao ASC;

-- Simulações com falha de exportação
SELECT
    s.NumSimulacao,
    s.DataSimulacao,
    ce.NumTentativas,
    ce.MensagemErro,
    ce.DataUltimaTentativa
FROM Simulacao s
INNER JOIN Controle_Exportacao ce ON s.NumSimulacao = ce.NumSimulacao
WHERE ce.StatusExportacao = 'FALHA'
ORDER BY ce.NumTentativas DESC, ce.DataUltimaTentativa DESC;

-- Taxa de sucesso de exportações
SELECT
    CONCAT(
        ROUND(
            SUM(CASE WHEN StatusExportacao = 'SUCESSO' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
            2
        ),
        '%'
    ) AS TaxaSucesso
FROM Controle_Exportacao;
```

### Monitoramento do Avaliador

```sql
USE AvaliacaoSimulacoes;

-- Estatísticas gerais
SELECT
    'Total Simulações' AS Metrica,
    COUNT(*) AS Valor
FROM Simulacoes_Avaliadas
UNION ALL
SELECT
    'Simulações Pendentes',
    COUNT(*)
FROM Simulacoes_Avaliadas
WHERE StatusAvaliacao = 'PENDENTE'
UNION ALL
SELECT
    'Interesse Científico',
    COUNT(*)
FROM Simulacoes_Avaliadas
WHERE StatusAvaliacao = 'INTERESSE_CIENTIFICO'
UNION ALL
SELECT
    'Total Corpos',
    COUNT(*)
FROM Corpos_Finais
UNION ALL
SELECT
    'Total Avaliações',
    COUNT(*)
FROM Status_Avaliacoes;

-- Simulações por status
SELECT
    StatusAvaliacao,
    COUNT(*) AS Quantidade,
    ROUND(AVG(QtdCorposFinais), 2) AS MediaCorpos,
    MIN(DataImportacao) AS MaisAntiga,
    MAX(DataImportacao) AS MaisRecente
FROM Simulacoes_Avaliadas
GROUP BY StatusAvaliacao;

-- Top 10 simulações com mais corpos
SELECT
    NumSimulacao,
    QtdCorposFinais,
    NumInteracoes,
    StatusAvaliacao,
    DataImportacao
FROM Simulacoes_Avaliadas
ORDER BY QtdCorposFinais DESC
LIMIT 10;

-- Histórico de limpezas
SELECT
    DataLimpeza,
    QtdSimulacoesRemovidas,
    QtdCorposRemovidos,
    TempoExecucao AS TempoSeg,
    DATEDIFF(NOW(), DataLimiteRemocao) AS DiasLimite
FROM Log_Limpeza
ORDER BY DataLimpeza DESC
LIMIT 10;

-- Tamanho dos bancos
SELECT
    table_schema AS 'Database',
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)',
    table_rows AS 'Rows (approx)'
FROM information_schema.TABLES
WHERE table_schema IN ('SimulacaoCorpos', 'AvaliacaoSimulacoes')
ORDER BY (data_length + index_length) DESC;
```

---

## Troubleshooting

### Problema: Event Scheduler não está ativo

```sql
-- Verificar
SHOW VARIABLES LIKE 'event_scheduler';

-- Se estiver OFF, ativar
SET GLOBAL event_scheduler = ON;

-- Para persistir após restart, adicionar ao my.cnf:
[mysqld]
event_scheduler=ON
```

### Problema: Exportação falhando sempre

```sql
-- 1. Verificar permissões entre schemas
SHOW GRANTS;

-- 2. Verificar log de erros
SELECT * FROM SimulacaoCorpos.Controle_Exportacao
WHERE StatusExportacao = 'FALHA'
ORDER BY DataUltimaTentativa DESC
LIMIT 5;

-- 3. Tentar exportar manualmente com mensagens de erro
CALL SimulacaoCorpos.sp_ExportarSimulacaoParaAvaliador(X);

-- 4. Verificar integridade das FKs
SELECT * FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA IN ('SimulacaoCorpos', 'AvaliacaoSimulacoes')
AND CONSTRAINT_TYPE = 'FOREIGN KEY';
```

### Problema: Banco crescendo muito rápido

```sql
-- 1. Verificar tamanho atual
SELECT
    table_schema,
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.TABLES
WHERE table_schema IN ('SimulacaoCorpos', 'AvaliacaoSimulacoes')
GROUP BY table_schema;

-- 2. Ajustar período de retenção (reduzir de 7 para 3 dias)
CALL AvaliacaoSimulacoes.sp_LimparDadosAntigos(3);

-- 3. Executar OPTIMIZE
OPTIMIZE TABLE AvaliacaoSimulacoes.Simulacoes_Avaliadas;
OPTIMIZE TABLE AvaliacaoSimulacoes.Corpos_Finais;

-- 4. No Gerador, considerar archiving de dados antigos
```

### Problema: Performance degradada

```sql
-- 1. Verificar índices
SHOW INDEX FROM SimulacaoCorpos.Corpos;
SHOW INDEX FROM AvaliacaoSimulacoes.Simulacoes_Avaliadas;

-- 2. Analisar queries lentas
SHOW VARIABLES LIKE 'slow_query_log';
SET GLOBAL slow_query_log = 'ON';

-- 3. Verificar fragmentação
SELECT
    TABLE_NAME,
    DATA_FREE / 1024 / 1024 AS 'Fragmentation (MB)'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA IN ('SimulacaoCorpos', 'AvaliacaoSimulacoes')
AND DATA_FREE > 0;

-- 4. Se fragmentado, otimizar
OPTIMIZE TABLE SimulacaoCorpos.Corpos;
```

---

## Contato e Suporte

**Desenvolvedores:** Grupo BD2
**Data:** 20/11/2025
**Versão:** 1.0

Para questões ou sugestões, consulte a documentação dos arquivos SQL individuais.

---

## Changelog

### v1.0 (20/11/2025)
- Implementação inicial completa
- Schema do Gerador (baseado em N1)
- Schema do Avaliador (novo)
- Integração entre schemas
- Rotina de limpeza automática
- Documentação completa
