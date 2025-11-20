# Sistema de Simulações Gravitacionais - BD2

Sistema integrado de banco de dados para gerenciamento de simulações gravitacionais, com dois processos distintos: **Gerador** e **Avaliador**.

## 🎯 Visão Geral

Este projeto implementa uma solução completa para:
- **Gerar** simulações gravitacionais com múltiplos corpos celestes
- **Armazenar** todas as iterações das simulações
- **Exportar** automaticamente resultados finais para avaliação
- **Avaliar** cientificamente as simulações de interesse
- **Limpar** automaticamente dados antigos

## 🏗️ Arquitetura

```
┌────────────────────────┐          ┌────────────────────────┐
│  GERADOR               │          │  AVALIADOR             │
│  SimulacaoCorpos       │─────────▶│  AvaliacaoSimulacoes   │
│                        │          │                        │
│  - Simulacao           │          │  - Simulacoes_Avaliadas│
│  - Resultados          │          │  - Resultados_Finais   │
│  - Corpos              │          │  - Corpos_Finais       │
│  - Controle_Exportacao │          │  - Status_Avaliacoes   │
└────────────────────────┘          └────────────────────────┘
```

## ✨ Funcionalidades

### ✅ Exportação Automática
- Trigger automático ao iniciar nova simulação
- Exporta apenas simulações com **3+ corpos finais**
- Transações ACID garantem atomicidade

### ✅ Retry Inteligente
- Retry automático em caso de falha (a cada 1 hora)
- Controle de status: PENDENTE, SUCESSO, FALHA
- Log de todas as tentativas

### ✅ Limpeza Automática
- Remove dados com mais de **7 dias** automaticamente
- Execução diária à meia-noite
- Log completo de operações

### ✅ Otimização
- **12 índices** estratégicos para grande volume
- Suporta até **2,7 trilhões** de registros/ano
- Queries otimizadas com EXPLAIN

## 📊 Volume de Dados Suportado

| Métrica | Valor |
|---------|-------|
| Simulações por dia | ~50 |
| Corpos por simulação | 200-1000 |
| Iterações por simulação | 100.000-500.000 |
| Registros anuais | ~2,7 trilhões |

## 🚀 Instalação Rápida

### Opção 1: Setup Automatizado (Recomendado)

```bash
# Entrar no MySQL
mysql -u root -p

# Executar setup completo
SOURCE setup_completo.sql;

# Carregar dados de teste
SOURCE dados_teste.sql;
```

### Opção 2: Instalação Manual

```bash
# 1. Schema do Gerador
mysql -u root -p < mysql_database_setup.sql

# 2. Schema do Avaliador
mysql -u root -p < schema_avaliador.sql

# 3. Integração
mysql -u root -p < integracao_gerador_avaliador.sql

# 4. Rotina de limpeza
mysql -u root -p < rotina_limpeza.sql

# 5. Dados de teste (opcional)
mysql -u root -p < dados_teste.sql
```

## 📁 Estrutura de Arquivos

```
bd2/
├── README.md                         ← Você está aqui
├── DOCUMENTACAO_COMPLETA.md          ← Documentação detalhada (modelos, diagramas)
├── README_DATABASE.md                ← Documentação do Gerador
│
├── mysql_database_setup.sql          ← Schema do Gerador (exercício N1)
├── schema_avaliador.sql              ← Schema do Avaliador
├── integracao_gerador_avaliador.sql  ← Stored procedures e triggers
├── rotina_limpeza.sql                ← Limpeza automática
│
├── setup_completo.sql                ← Setup automatizado (executa todos)
└── dados_teste.sql                   ← Dados de teste (6 simulações)
```

## 📖 Documentação

### Leitura Rápida (5 min)
- **README.md** (este arquivo): Visão geral e instalação

### Documentação Completa (30 min)
- **DOCUMENTACAO_COMPLETA.md**: Modelos físicos, diagramas ER, índices, stored procedures, exemplos

### Documentação Técnica do Gerador
- **README_DATABASE.md**: Detalhes do schema SimulacaoCorpos

## 🔧 Principais Componentes

### Stored Procedures

| Procedure | Schema | Descrição |
|-----------|--------|-----------|
| `sp_ExportarSimulacaoParaAvaliador` | Gerador | Exporta simulação com transação |
| `sp_RetentarExportacoesFalhadas` | Gerador | Retry de exportações falhadas |
| `sp_LimparDadosAntigos` | Avaliador | Remove dados antigos |
| `sp_PreviewLimpeza` | Avaliador | Preview sem remover |
| `sp_AvaliarSimulacao` | Avaliador | Registra avaliação científica |
| `sp_EstatisticasSimulacao` | Avaliador | Estatísticas completas |

### Triggers

| Trigger | Tabela | Evento | Ação |
|---------|--------|--------|------|
| `trg_ExportarAntesNovaSimulacao` | Simulacao | AFTER INSERT | Exporta simulação anterior |

### Events (Agendados)

| Event | Frequência | Ação |
|-------|-----------|------|
| `evt_RetryExportacoesFalhadas` | 1 hora | Retry de falhas |
| `evt_LimpezaAutomatica` | Diária (meia-noite) | Limpa dados >7 dias |

## 💡 Exemplos de Uso

### Criar Nova Simulação

```sql
USE SimulacaoCorpos;

-- 1. Criar simulação
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES (NOW(), 250, 200000, 10000);

SET @sim = LAST_INSERT_ID();

-- 2. Adicionar iteração final
INSERT INTO Resultados (NumSimulacao, NumIteracao) VALUES (@sim, 200000);

-- 3. Adicionar corpos finais
INSERT INTO Corpos (NumSimulacao, NumIteracao, NomeCorpo, MassaCorpo, PosX, PosY, VelX, VelY, DensidadeCorpo)
VALUES
    (@sim, 200000, 'Estrela', 2e30, 0, 0, 0, 0, 1400),
    (@sim, 200000, 'Planeta_1', 6e24, 1.5e11, 0, 0, 30000, 5500),
    (@sim, 200000, 'Planeta_2', 4e24, -2e11, 0, 0, -25000, 5200);

-- 4. Criar outra simulação (trigger exporta a anterior automaticamente)
INSERT INTO Simulacao (DataSimulacao, QtdCorposInicial, NumInteracoes, TempoInteracoes)
VALUES (NOW(), 200, 150000, 8000);
```

### Monitorar Exportações

```sql
-- Ver status de todas as exportações
SELECT
    ce.NumSimulacao,
    s.DataSimulacao,
    ce.StatusExportacao,
    ce.NumTentativas,
    ce.QtdCorposFinais
FROM SimulacaoCorpos.Controle_Exportacao ce
INNER JOIN SimulacaoCorpos.Simulacao s ON ce.NumSimulacao = s.NumSimulacao
ORDER BY ce.NumSimulacao DESC;
```

### Avaliar Simulação

```sql
USE AvaliacaoSimulacoes;

-- Registrar avaliação científica
CALL sp_AvaliarSimulacao(
    5,                              -- NumSimulacao
    'Dr. João Silva',               -- Avaliador
    4,                              -- Nota (1-5)
    'Configuração estável interessante'  -- Observações
);

-- Ver simulações de interesse científico
SELECT * FROM vw_Simulacoes_Interesse_Cientifico;
```

### Executar Limpeza

```sql
USE AvaliacaoSimulacoes;

-- Preview (sem remover)
CALL sp_PreviewLimpeza(7);

-- Executar limpeza
CALL sp_LimparDadosAntigos(7);

-- Ver histórico
CALL sp_HistoricoLimpeza(10);
```

## 🎯 Requisitos Atendidos

| ✅ Requisito | Implementação |
|-------------|---------------|
| Dois bancos integrados | SimulacaoCorpos + AvaliacaoSimulacoes |
| Banco do Gerador = N1 | mysql_database_setup.sql |
| ~50 simulações/dia | ✅ Suportado |
| 200+ corpos mínimo | ✅ CHECK constraint |
| 100k-500k iterações | ✅ CHECK constraint |
| Stored Procedure exportação | sp_ExportarSimulacaoParaAvaliador |
| Execução automática | trg_ExportarAntesNovaSimulacao |
| Atomicidade (tudo ou nada) | Transações SQL |
| Retry em caso de falha | evt_RetryExportacoesFalhadas |
| Filtro: 3+ corpos | Verificação na SP |
| Limpeza >1 semana | evt_LimpezaAutomatica (7 dias) |
| Índices otimizados | 12 índices criados |
| Schema do Avaliador | schema_avaliador.sql |
| Modelos físicos | DOCUMENTACAO_COMPLETA.md |
| Scripts completos | Todos os .sql |

## 🔍 Monitoramento

### Dashboard de Status

```sql
-- Status geral do sistema
SELECT 'Gerador: Total Simulações' AS Metrica,
       COUNT(*) AS Valor
FROM SimulacaoCorpos.Simulacao
UNION ALL
SELECT 'Gerador: Exportações Sucesso',
       COUNT(*)
FROM SimulacaoCorpos.Controle_Exportacao
WHERE StatusExportacao = 'SUCESSO'
UNION ALL
SELECT 'Avaliador: Total Simulações',
       COUNT(*)
FROM AvaliacaoSimulacoes.Simulacoes_Avaliadas
UNION ALL
SELECT 'Avaliador: Interesse Científico',
       COUNT(*)
FROM AvaliacaoSimulacoes.Simulacoes_Avaliadas
WHERE StatusAvaliacao = 'INTERESSE_CIENTIFICO';
```

### Tamanho dos Bancos

```sql
SELECT
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.TABLES
WHERE table_schema IN ('SimulacaoCorpos', 'AvaliacaoSimulacoes')
GROUP BY table_schema;
```

## 🐛 Troubleshooting

### Event Scheduler não está ativo

```sql
-- Verificar
SHOW VARIABLES LIKE 'event_scheduler';

-- Ativar
SET GLOBAL event_scheduler = ON;
```

### Exportação falhando

```sql
-- Ver erros
SELECT * FROM SimulacaoCorpos.Controle_Exportacao
WHERE StatusExportacao = 'FALHA'
ORDER BY DataUltimaTentativa DESC;

-- Tentar manualmente
CALL SimulacaoCorpos.sp_ExportarSimulacaoParaAvaliador(X);
```

### Ver logs de limpeza

```sql
SELECT * FROM AvaliacaoSimulacoes.Log_Limpeza
ORDER BY DataLimpeza DESC
LIMIT 10;
```

## 🧪 Testes

O arquivo `dados_teste.sql` cria 6 cenários de teste:

1. **Simulação 1**: 3 corpos (exemplo original) ✅
2. **Simulação 2**: 5 corpos finais ✅ EXPORTADA
3. **Simulação 3**: 2 corpos finais ❌ NÃO EXPORTADA (< 3)
4. **Simulação 4**: 3 corpos finais (limite mínimo) ✅ EXPORTADA
5. **Simulação 5**: 8 corpos finais (sistema complexo) ✅ EXPORTADA
6. **Simulação 6**: 4 corpos, >7 dias ⏳ Será limpa automaticamente

Para executar os testes:

```bash
mysql -u root -p < dados_teste.sql
```

## 📊 Views Úteis

### Schema Avaliador

```sql
-- Simulações completas com avaliações
SELECT * FROM AvaliacaoSimulacoes.vw_Simulacoes_Completas;

-- Simulações de interesse científico
SELECT * FROM AvaliacaoSimulacoes.vw_Simulacoes_Interesse_Cientifico;

-- Simulações pendentes de avaliação
SELECT * FROM AvaliacaoSimulacoes.vw_Simulacoes_Pendentes;
```

## 🔐 Segurança

- **Transações ACID**: Garantem consistência
- **Foreign Keys**: Integridade referencial
- **CHECK Constraints**: Validação de dados
- **ON DELETE CASCADE**: Limpeza automática de órfãos
- **InnoDB Engine**: Durabilidade e recuperação

## 📈 Performance

### Índices Críticos

```sql
-- Exportação otimizada
idx_resultados_sim_iter (NumSimulacao, NumIteracao DESC)
idx_corpos_exportacao (NumSimulacao, NumIteracao)

-- Limpeza otimizada
idx_simulacoes_data_importacao (DataImportacao)

-- Consultas otimizadas
idx_simulacoes_status (StatusAvaliacao)
idx_corpos_finais_simulacao (NumSimulacao)
```

### Análise de Queries

```sql
-- Verificar uso de índices
EXPLAIN SELECT MAX(NumIteracao)
FROM Resultados
WHERE NumSimulacao = 1;
```

## 🎓 Conceitos Aplicados

- ✅ Normalização de dados (3FN)
- ✅ Stored Procedures
- ✅ Triggers
- ✅ Events (agendamento)
- ✅ Transações ACID
- ✅ Índices compostos
- ✅ Foreign Keys com CASCADE
- ✅ CHECK Constraints
- ✅ Views
- ✅ Integração entre schemas
- ✅ Retry pattern
- ✅ Data archiving/cleanup

## 📝 Requisitos Técnicos

- **MySQL**: 5.7+ ou MariaDB 10.2+
- **Privilégios**: CREATE DATABASE, CREATE EVENT
- **Event Scheduler**: Ativado (ON)
- **InnoDB Engine**: Suporte a transações

## 👥 Autores

Desenvolvido para o curso de Banco de Dados 2

**Data**: 20/11/2025
**Versão**: 1.0

## 📄 Licença

Este projeto é parte do material acadêmico do curso de Banco de Dados 2.

---

## 🚀 Quick Start

```bash
# 1. Clone/baixe o repositório
cd bd2

# 2. Instale tudo
mysql -u root -p < setup_completo.sql

# 3. Carregue dados de teste
mysql -u root -p < dados_teste.sql

# 4. Explore!
mysql -u root -p
USE SimulacaoCorpos;
SELECT * FROM Simulacao;

USE AvaliacaoSimulacoes;
SELECT * FROM vw_Simulacoes_Completas;
```

## 📚 Próximos Passos

1. ✅ Ler `README.md` (você está aqui)
2. 📖 Ler `DOCUMENTACAO_COMPLETA.md` para detalhes técnicos
3. 🚀 Executar `setup_completo.sql`
4. 🧪 Executar `dados_teste.sql`
5. 🔍 Explorar os dados com as queries de exemplo
6. 💡 Experimentar criar suas próprias simulações

---

**Dúvidas?** Consulte a documentação completa em `DOCUMENTACAO_COMPLETA.md`
