# Banco de Dados MySQL - Simulação de Corpos

## Visão Geral

Este projeto implementa um banco de dados MySQL para armazenar dados de simulações de corpos celestes, incluindo suas posições, velocidades e propriedades físicas ao longo de múltiplas iterações.

---

## 1. Modelo Lógico

```
┌─────────────────────────┐
│      SIMULACAO          │
├─────────────────────────┤
│ NumSimulacao (PK)       │
│ DataSimulacao           │
│ QtdCorposInicial        │
│ NumInteracoes           │
│ TempoInteracoes         │
└───────────┬─────────────┘
            │
            │ 1
            │
            │ N
            │
┌───────────▼─────────────┐
│      RESULTADOS         │
├─────────────────────────┤
│ NumSimulacao (PK, FK)   │
│ NumIteracao (PK)        │
└───────────┬─────────────┘
            │
            │ 1
            │
            │ N
            │
┌───────────▼─────────────┐
│        CORPOS           │
├─────────────────────────┤
│ IdCorpo (PK)            │
│ NumSimulacao (FK)       │
│ NumIteracao (FK)        │
│ NomeCorpo               │
│ MassaCorpo              │
│ PosX                    │
│ PosY                    │
│ VelX                    │
│ VelY                    │
│ DensidadeCorpo          │
└─────────────────────────┘
```

### Relacionamentos

- **Simulacao → Resultados**: Uma simulação possui múltiplos resultados (1:N)
- **Resultados → Corpos**: Um resultado possui múltiplos corpos (1:N)

---

## 2. Modelo Físico

### Tabela: Simulacao

| Campo            | Tipo         | Restrições           | Descrição                              |
|------------------|--------------|----------------------|----------------------------------------|
| NumSimulacao     | INT          | PK, AUTO_INCREMENT   | Identificador único da simulação       |
| DataSimulacao    | VARCHAR(50)  | NOT NULL             | Data/hora da simulação                 |
| QtdCorposInicial | INT          | NOT NULL, > 0        | Quantidade inicial de corpos           |
| NumInteracoes    | INT          | NOT NULL, > 0        | Número de iterações planejadas         |
| TempoInteracoes  | INT          | NOT NULL, > 0        | Tempo total de interações (segundos)   |

### Tabela: Resultados

| Campo         | Tipo | Restrições              | Descrição                           |
|---------------|------|-------------------------|-------------------------------------|
| NumSimulacao  | INT  | PK, FK → Simulacao      | Referência à simulação              |
| NumIteracao   | INT  | PK                      | Número da iteração (0, 1, 2, ...)   |

**Chave Primária Composta**: (NumSimulacao, NumIteracao)

### Tabela: Corpos

| Campo          | Tipo         | Restrições                   | Descrição                          |
|----------------|--------------|------------------------------|------------------------------------|
| IdCorpo        | INT          | PK, AUTO_INCREMENT           | Identificador único do corpo       |
| NumSimulacao   | INT          | FK → Resultados              | Referência à simulação             |
| NumIteracao    | INT          | FK → Resultados              | Referência à iteração              |
| NomeCorpo      | VARCHAR(100) | NOT NULL                     | Nome do corpo (ex: Sol, Terra)     |
| MassaCorpo     | FLOAT        | NOT NULL, > 0                | Massa do corpo (kg)                |
| PosX           | FLOAT        | NOT NULL                     | Posição X (metros)                 |
| PosY           | FLOAT        | NOT NULL                     | Posição Y (metros)                 |
| VelX           | FLOAT        | NOT NULL                     | Velocidade X (m/s)                 |
| VelY           | FLOAT        | NOT NULL                     | Velocidade Y (m/s)                 |
| DensidadeCorpo | FLOAT        | NOT NULL, > 0                | Densidade (kg/m³)                  |

**Chave Estrangeira Composta**: (NumSimulacao, NumIteracao) → Resultados

---

## 3. Definição das Chaves

### Chaves Primárias

- **Simulacao**: `NumSimulacao`
- **Resultados**: `(NumSimulacao, NumIteracao)` - Chave composta
- **Corpos**: `IdCorpo` - Chave surrogate para facilitar operações

### Chaves Estrangeiras

- **Resultados.NumSimulacao** → **Simulacao.NumSimulacao**
  - ON DELETE CASCADE
  - ON UPDATE CASCADE

- **Corpos.(NumSimulacao, NumIteracao)** → **Resultados.(NumSimulacao, NumIteracao)**
  - ON DELETE CASCADE
  - ON UPDATE CASCADE

### Índices

- Índices automáticos nas chaves primárias
- `idx_corpos_nome` em Corpos(NomeCorpo)
- `idx_resultados_iteracao` em Resultados(NumIteracao)
- Índices automáticos nas chaves estrangeiras

---

## 4. Consultas SQL (SELECTs)

### 4.1. Listar todos os resultados de uma determinada simulação

```sql
SELECT
    r.NumSimulacao,
    r.NumIteracao,
    s.DataSimulacao,
    COUNT(c.IdCorpo) AS QtdCorpos
FROM Resultados r
INNER JOIN Simulacao s ON r.NumSimulacao = s.NumSimulacao
LEFT JOIN Corpos c ON r.NumSimulacao = c.NumSimulacao
                   AND r.NumIteracao = c.NumIteracao
WHERE r.NumSimulacao = ?  -- Parâmetro da consulta
GROUP BY r.NumSimulacao, r.NumIteracao, s.DataSimulacao
ORDER BY r.NumIteracao;
```

### 4.2. Dado um determinado resultado, listar os corpos do resultado

```sql
SELECT
    c.IdCorpo,
    c.NomeCorpo,
    c.MassaCorpo,
    c.PosX,
    c.PosY,
    c.VelX,
    c.VelY,
    c.DensidadeCorpo
FROM Corpos c
WHERE c.NumSimulacao = ?     -- Parâmetro: número da simulação
  AND c.NumIteracao = ?      -- Parâmetro: número da iteração
ORDER BY c.NomeCorpo;
```

### 4.3. Listar todos os resultados de uma simulação, com os respectivos corpos

```sql
SELECT
    r.NumIteracao,
    c.NomeCorpo,
    c.MassaCorpo,
    c.PosX,
    c.PosY,
    c.VelX,
    c.VelY,
    c.DensidadeCorpo
FROM Resultados r
INNER JOIN Corpos c ON r.NumSimulacao = c.NumSimulacao
                    AND r.NumIteracao = c.NumIteracao
WHERE r.NumSimulacao = ?     -- Parâmetro: número da simulação
ORDER BY r.NumIteracao, c.NomeCorpo;
```

### 4.4. Informar a quantidade de resultados para uma determinada simulação

```sql
SELECT
    s.NumSimulacao,
    s.DataSimulacao,
    COUNT(r.NumIteracao) AS QtdResultados
FROM Simulacao s
LEFT JOIN Resultados r ON s.NumSimulacao = r.NumSimulacao
WHERE s.NumSimulacao = ?     -- Parâmetro: número da simulação
GROUP BY s.NumSimulacao, s.DataSimulacao;
```

### 4.5. Informar a quantidade final de corpos de uma simulação

```sql
SELECT
    s.NumSimulacao,
    s.DataSimulacao,
    MAX(r.NumIteracao) AS UltimaIteracao,
    COUNT(c.IdCorpo) AS QtdCorposFinais
FROM Simulacao s
INNER JOIN Resultados r ON s.NumSimulacao = r.NumSimulacao
LEFT JOIN Corpos c ON r.NumSimulacao = c.NumSimulacao
                   AND r.NumIteracao = c.NumIteracao
WHERE s.NumSimulacao = ?     -- Parâmetro: número da simulação
  AND r.NumIteracao = (
      SELECT MAX(r2.NumIteracao)
      FROM Resultados r2
      WHERE r2.NumSimulacao = s.NumSimulacao
  )
GROUP BY s.NumSimulacao, s.DataSimulacao;
```

### 4.6. Listar os corpos do último resultado de uma simulação

```sql
SELECT
    c.IdCorpo,
    c.NumIteracao,
    c.NomeCorpo,
    c.MassaCorpo,
    c.PosX,
    c.PosY,
    c.VelX,
    c.VelY,
    c.DensidadeCorpo
FROM Corpos c
INNER JOIN (
    SELECT NumSimulacao, MAX(NumIteracao) AS MaxIteracao
    FROM Resultados
    WHERE NumSimulacao = ?   -- Parâmetro: número da simulação
    GROUP BY NumSimulacao
) ultimo ON c.NumSimulacao = ultimo.NumSimulacao
        AND c.NumIteracao = ultimo.MaxIteracao
ORDER BY c.NomeCorpo;
```

---

## 5. Como Utilizar

### 5.1. Criar o Banco de Dados

```bash
mysql -u root -p < mysql_database_setup.sql
```

### 5.2. Conectar ao Banco

```bash
mysql -u root -p SimulacaoCorpos
```

### 5.3. Testar com Dados de Exemplo

O script já inclui dados de exemplo com:
- 1 simulação (Sol, Terra, Lua)
- 3 iterações (0, 50, 100)
- 9 corpos (3 por iteração)

### 5.4. Executar as Consultas

As consultas estão documentadas no arquivo `mysql_database_setup.sql` nas seções 6.1 a 6.6.

---

## 6. Recursos Adicionais

### Stored Procedures

- `sp_CriarSimulacao`: Cria uma nova simulação
- `sp_AdicionarResultado`: Adiciona um resultado a uma simulação
- `sp_AdicionarCorpo`: Adiciona um corpo a um resultado

### Views

- `vw_CorposCompleto`: Visão completa de corpos com dados da simulação
- `vw_EstatisticasSimulacao`: Estatísticas gerais das simulações

---

## 7. Estrutura de Arquivos

```
bd2/
├── mysql_database_setup.sql    # Script SQL completo
└── README_DATABASE.md          # Esta documentação
```

---

## 8. Considerações de Design

### Por que usar IdCorpo como PK em vez de chave composta?

- **Simplicidade**: Facilita referências futuras e operações de UPDATE/DELETE
- **Performance**: Índice único em INT é mais eficiente que índice composto
- **Flexibilidade**: Permite maior flexibilidade para futuras extensões

### Por que CASCADE nas FKs?

- **Integridade**: Quando uma simulação é deletada, todos os resultados e corpos relacionados são removidos automaticamente
- **Consistência**: Evita órfãos no banco de dados
- **Manutenção**: Simplifica operações de limpeza

### Constraints e Validações

- Massa e densidade sempre positivas (CHECK > 0)
- Quantidade de corpos inicial sempre positiva
- Número de interações e tempo sempre positivos

---

## 9. Exemplos de Uso

### Criar uma nova simulação

```sql
CALL sp_CriarSimulacao(
    '2025-11-20 15:30:00',  -- Data
    5,                       -- Quantidade inicial de corpos
    1000,                    -- Número de iterações
    7200,                    -- Tempo (segundos)
    @novo_id                 -- Variável de saída
);

SELECT @novo_id AS NovaSimulacao;
```

### Consultar evolução de um corpo

```sql
SELECT
    c.NumIteracao,
    c.NomeCorpo,
    c.PosX,
    c.PosY,
    SQRT(POWER(c.PosX, 2) + POWER(c.PosY, 2)) AS DistanciaOrigem
FROM Corpos c
WHERE c.NumSimulacao = 1
  AND c.NomeCorpo = 'Terra'
ORDER BY c.NumIteracao;
```

---

## 10. Troubleshooting

### Erro de Foreign Key

Se ocorrer erro ao inserir dados:
1. Verifique se a simulação existe antes de inserir resultados
2. Verifique se o resultado existe antes de inserir corpos

### Performance

Para grandes volumes de dados:
1. Considere adicionar mais índices em campos frequentemente consultados
2. Use EXPLAIN para analisar planos de consulta
3. Considere particionamento para tabelas muito grandes

---

## Autor

Banco de dados desenvolvido baseado no diagrama UML de classes fornecido.

Data: 20/11/2025
