# Sistema de Controle de Exportação - Correção Aplicada

## 🔧 Problema Identificado

O erro `#1308 - LEAVE with no matching label` ocorreu porque os procedimentos armazenados estavam usando a instrução `LEAVE` sem que o bloco `BEGIN` principal tivesse um rótulo (label) correspondente.

## ✅ Correção Aplicada

### Antes (com erro):
```sql
CREATE PROCEDURE sp_ExportarSimulacaoParaAvaliador(
    IN p_NumSimulacao INT
)
BEGIN
    ...
    LEAVE sp_ExportarSimulacaoParaAvaliador;  -- ERRO: sem label
END //
```

### Depois (corrigido):
```sql
CREATE PROCEDURE sp_ExportarSimulacaoParaAvaliador(
    IN p_NumSimulacao INT
)
proc_label: BEGIN  -- Adicionar rótulo aqui
    ...
    LEAVE proc_label;  -- Usar o rótulo correto
END //
```

## 📁 Arquivos Criados

### 1. `controle_exportacao.sql`
Contém toda a estrutura corrigida do sistema de controle de exportação:
- Tabela `Controle_Exportacao`
- Índices otimizados
- Procedimentos armazenados (corrigidos):
  - `sp_ExportarSimulacaoParaAvaliador`
  - `sp_RetentarExportacoesFalhadas`
  - `sp_LimparDadosAntigos`
  - `sp_PreviewLimpeza`
  - `sp_HistoricoLimpeza`
- Trigger `trg_ExportarAntesNovaSimulacao`
- Eventos automáticos:
  - `evt_RetryExportacoesFalhadas` (a cada 1 hora)
  - `evt_LimpezaAutomatica` (diária)

### 2. `dados_teste_exportacao.sql`
Contém dados de teste para validar o sistema:
- **Simulação 2**: 5 corpos finais (será exportada ✅)
- **Simulação 3**: 2 corpos finais (NÃO será exportada ❌)
- **Simulação 4**: 3 corpos finais (será exportada ✅)
- **Simulação 5**: 8 corpos finais (sistema complexo, será exportada ✅)
- **Simulação 6**: 4 corpos, mais de 7 dias (para testar limpeza ✅)

## 🚀 Como Usar

### Passo 1: Executar a estrutura principal
```bash
mysql -u root -p < controle_exportacao.sql
```

### Passo 2: (Opcional) Carregar dados de teste
```bash
mysql -u root -p < dados_teste_exportacao.sql
```

## 🔍 Funcionalidades do Sistema

### 1. Exportação Automática
- Exporta apenas simulações com 3 ou mais corpos finais
- Registra todas as tentativas de exportação
- Marca simulações como PENDENTE, SUCESSO ou FALHA

### 2. Retry Automático
- A cada 1 hora, tenta reexportar simulações que falharam
- Incrementa contador de tentativas

### 3. Limpeza Automática
- Diariamente, remove dados com mais de 7 dias
- Mantém integridade referencial
- Otimiza tabelas após limpeza
- Registra todas as operações em log

### 4. Trigger de Exportação
- Ao inserir nova simulação, tenta exportar a simulação anterior
- Garante que simulações não fiquem esquecidas

## 📊 Comandos Úteis

### Verificar status de exportação:
```sql
USE SimulacaoCorpos;
SELECT * FROM Controle_Exportacao ORDER BY NumSimulacao;
```

### Exportar simulação manualmente:
```sql
CALL sp_ExportarSimulacaoParaAvaliador(2);
```

### Ver preview de limpeza (sem executar):
```sql
USE AvaliacaoSimulacoes;
CALL sp_PreviewLimpeza(7);  -- Mostra o que seria removido com 7 dias
```

### Executar limpeza manual:
```sql
CALL sp_LimparDadosAntigos(7);  -- Remove dados com mais de 7 dias
```

### Ver histórico de limpezas:
```sql
CALL sp_HistoricoLimpeza(10);  -- Últimas 10 limpezas
```

### Retentar exportações falhadas:
```sql
USE SimulacaoCorpos;
CALL sp_RetentarExportacoesFalhadas();
```

## 🎯 Regras de Exportação

1. ✅ **Será exportada** se:
   - Simulação tem resultados finais
   - Tem 3 ou mais corpos na última iteração
   - Não foi exportada anteriormente com sucesso

2. ❌ **NÃO será exportada** se:
   - Simulação ainda não tem resultados (marca como PENDENTE)
   - Tem menos de 3 corpos finais (marca como SUCESSO com mensagem)
   - Já foi exportada com sucesso anteriormente

3. 🔄 **Será retentada** se:
   - Status = 'FALHA'
   - Evento automático ou chamada manual do retry

## 📈 Monitoramento

### Ver estatísticas de exportação:
```sql
SELECT
    StatusExportacao,
    COUNT(*) AS Quantidade,
    AVG(NumTentativas) AS MediaTentativas
FROM SimulacaoCorpos.Controle_Exportacao
GROUP BY StatusExportacao;
```

### Ver simulações exportadas:
```sql
SELECT
    s.NumSimulacao,
    s.QtdCorposFinais,
    s.StatusAvaliacao,
    COUNT(DISTINCT sa.IdAvaliacao) AS NumAvaliacoes
FROM AvaliacaoSimulacoes.Simulacoes_Avaliadas s
LEFT JOIN AvaliacaoSimulacoes.Status_Avaliacoes sa ON s.NumSimulacao = sa.NumSimulacao
GROUP BY s.NumSimulacao;
```

## ⚠️ Observações Importantes

1. **Event Scheduler**: O sistema ativa o event scheduler automaticamente. Se necessário desativar:
   ```sql
   SET GLOBAL event_scheduler = OFF;
   ```

2. **Transações**: Todas as operações de exportação usam transações para garantir atomicidade.

3. **Integridade**: A tabela `Controle_Exportacao` usa CASCADE para manter consistência com `Simulacao`.

4. **Performance**: Os índices criados otimizam as consultas mais frequentes:
   - Por status de exportação
   - Por data de tentativa
   - Por simulação e iteração

## 🐛 Troubleshooting

### Problema: Eventos não estão executando
**Solução**: Verificar se event scheduler está ativo:
```sql
SHOW VARIABLES LIKE 'event_scheduler';
SET GLOBAL event_scheduler = ON;
```

### Problema: Exportação falha por falta de tabelas no Avaliador
**Solução**: Executar primeiro o script de criação do schema Avaliador:
```bash
mysql -u root -p < schema_avaliador.sql
```

### Problema: Procedimento não encontra simulação
**Solução**: Verificar se a simulação existe no banco Gerador:
```sql
USE SimulacaoCorpos;
SELECT * FROM Simulacao WHERE NumSimulacao = X;
```

## 📝 Diferenças da Versão Original

1. ✅ Corrigidos todos os blocos BEGIN com rótulos apropriados
2. ✅ Substituídos `LEAVE nome_procedure` por `LEAVE proc_label`
3. ✅ Mantida toda a funcionalidade original
4. ✅ Adicionados comentários explicativos nas correções
5. ✅ Separação entre estrutura e dados de teste

---

**Versão**: 1.0 (Corrigida)
**Data**: 2025-11-20
**Status**: ✅ Pronto para produção
