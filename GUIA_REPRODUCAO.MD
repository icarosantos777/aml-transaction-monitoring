# GUIA DE REPRODUÇÃO — AML Transaction Monitoring SAML-D

Este arquivo é a **fonte de contexto para continuar o projeto em outra conversa ou com outra IA**.

Ele contém:

- objetivo e escopo;
- ambiente do Google Cloud;
- estrutura dos dados;
- papel do notebook Python;
- regras que não podem ser alteradas;
- seis consultas SQL completas;
- resultados esperados;
- validações;
- configuração do Looker Studio;
- erros comuns;
- instruções para outra IA continuar o trabalho.

---

# 1. Instrução principal para outra IA

Ao receber este arquivo, siga estas regras:

1. Leia o documento inteiro antes de sugerir alterações.
2. Não modifique os limiares das regras antes de reproduzir os resultados.
3. Não use `is_laundering` ou `transaction_pattern` para gerar alertas.
4. Use essas labels somente na etapa de avaliação.
5. Mantenha contas como `STRING`.
6. Agrupe sempre por `payment_currency`; não some moedas diferentes.
7. Execute os SQLs na ordem indicada.
8. Valide o resultado de cada etapa antes de avançar.
9. Caso um número não coincida, investigue a origem da diferença. Não altere o resultado esperado no README apenas para fazê-lo combinar.
10. Não apresente os limiares como limites regulatórios oficiais.
11. Trabalhe passo a passo e explique cada consulta em linguagem simples.
12. Não transforme o projeto em machine learning, sistema de produção ou projeto excessivamente grande.

## Limite de confiança

As lógicas finais, os limiares e os resultados foram preservados no histórico do projeto.

Os seis arquivos abaixo formam a versão reutilizável do pipeline. Eles devem ser executados novamente no BigQuery antes de afirmar que o repositório público reproduz exatamente os números.

A reprodução exata começa quando existe a tabela:

```text
saml-d-aml-monitoring.aml_monitoring.raw_transactions
```

com **9.504.852 registros** e o esquema descrito neste documento.

---

# 2. Objetivo do projeto

Construir um MVP de portfólio de monitoramento transacional AML/PLD usando o dataset sintético SAML-D.

O projeto demonstra:

- Python e Pandas para análise preliminar;
- BigQuery e SQL;
- tratamento e validação de dados;
- criação de regras AML explicáveis;
- prevenção de target leakage;
- avaliação de alertas;
- criação de uma fila operacional;
- dashboard no Looker Studio;
- Claude Code e IA generativa como apoio ao desenvolvimento.

A IA é usada para:

- revisão de consultas;
- organização do repositório;
- documentação;
- explicação do código.

A IA **não decide quais transações são alertadas**.

---

# 3. Escopo final

O projeto possui somente duas regras:

1. `STRUCTURING`
2. `SMURFING`

Não incluir nesta versão:

- machine learning;
- baseline completo por conta;
- conversão cambial;
- SQL recursivo;
- layering com múltiplos saltos;
- regras para todas as tipologias;
- orquestração;
- dashboard com várias páginas.

Esses pontos podem aparecer apenas como evoluções futuras.

---

# 4. Ambiente

## Google Cloud Project ID

```text
saml-d-aml-monitoring
```

## BigQuery dataset

```text
aml_monitoring
```

## Ambiente utilizado

```text
BigQuery Sandbox
```

Evitar operações DML desnecessárias:

```text
INSERT
UPDATE
DELETE
MERGE
```

Priorizar:

```text
SELECT
CREATE OR REPLACE VIEW
CREATE OR REPLACE TABLE AS SELECT
```

Todos os objetos devem estar na mesma região do BigQuery.

---

# 5. Arquitetura

```text
SAML-D CSV
    │
    ├── Python / Pandas
    │      └── 01_preliminary_analysis.ipynb
    │
    └── BigQuery
           └── ext_saml_d
                  ↓
              raw_transactions
                  ↓
              stg_transactions
                  ↓
          ┌───────┴────────┐
          ↓                ↓
 rule_structuring    rule_smurfing
          └───────┬────────┘
                  ↓
                alerts
                  ↓
           rule_evaluation
                  ↓
          dashboard_summary
                  ↓
             Looker Studio
```

---

# 6. Notebook Python

Nome recomendado:

```text
notebooks/01_preliminary_analysis.ipynb
```

## Papel do notebook

O notebook analisa apenas as primeiras 10.000 linhas.

Ele serve para:

- conferir as colunas;
- validar os tipos;
- manter contas como texto;
- criar `Transaction_timestamp`;
- verificar erros na conversão de data e horário;
- observar nulos;
- observar preliminarmente valores, labels e categorias.

Ele **não produz os números finais** do projeto.

As primeiras 10.000 linhas não constituem uma amostra aleatória.

## Código mínimo esperado

```python
import pandas as pd

FILE_PATH = "/content/drive/MyDrive/SAML-D.csv"

df_sample = pd.read_csv(
    FILE_PATH,
    nrows=10_000,
    dtype={
        "Sender_account": "string",
        "Receiver_account": "string",
    },
)

df_sample.info()
df_sample.head()
```

Criar o timestamp:

```python
df_sample["Transaction_timestamp"] = pd.to_datetime(
    df_sample["Date"] + " " + df_sample["Time"],
    errors="coerce",
)
```

Verificar a qualidade:

```python
quality_check = pd.DataFrame({
    "dtype": df_sample.dtypes.astype(str),
    "null_count": df_sample.isna().sum(),
    "unique_values": df_sample.nunique(dropna=False),
})

quality_check
```

Conclusão que deve aparecer no notebook:

> A amostra foi usada para validar a estrutura do arquivo. A análise completa e as métricas finais foram calculadas no BigQuery sobre 9.504.852 registros.

---

# 7. Dataset completo

## Tabela externa

```text
saml-d-aml-monitoring.aml_monitoring.ext_saml_d
```

Ela aponta para o CSV completo.

A configuração do caminho é específica do Google Drive ou do ambiente utilizado. Ela não é a parte principal da reprodução.

## Cabeçalhos esperados no CSV original

```text
Date
Time
Sender_account
Receiver_account
Amount
Payment_currency
Received_currency
Sender_bank_location
Receiver_bank_location
Payment_type
Is_laundering
Laundering_type
```

## Tabela raw esperada

```text
saml-d-aml-monitoring.aml_monitoring.raw_transactions
```

Colunas:

```text
date_raw
time_raw
sender_account_raw
receiver_account_raw
amount_raw
payment_currency_raw
received_currency_raw
sender_bank_location_raw
receiver_bank_location_raw
payment_type_raw
is_laundering_raw
laundering_type_raw
```

Todas as colunas da raw devem estar como `STRING`.

## Criação da raw quando a tabela externa usa os nomes originais

```sql
CREATE OR REPLACE TABLE
  `saml-d-aml-monitoring.aml_monitoring.raw_transactions`
AS

SELECT
  CAST(Date AS STRING) AS date_raw,
  CAST(Time AS STRING) AS time_raw,
  CAST(Sender_account AS STRING) AS sender_account_raw,
  CAST(Receiver_account AS STRING) AS receiver_account_raw,
  CAST(Amount AS STRING) AS amount_raw,
  CAST(Payment_currency AS STRING) AS payment_currency_raw,
  CAST(Received_currency AS STRING) AS received_currency_raw,
  CAST(Sender_bank_location AS STRING) AS sender_bank_location_raw,
  CAST(Receiver_bank_location AS STRING) AS receiver_bank_location_raw,
  CAST(Payment_type AS STRING) AS payment_type_raw,
  CAST(Is_laundering AS STRING) AS is_laundering_raw,
  CAST(Laundering_type AS STRING) AS laundering_type_raw

FROM
  `saml-d-aml-monitoring.aml_monitoring.ext_saml_d`;
```

Se a tabela externa já possui os nomes com sufixo `_raw`, basta:

```sql
CREATE OR REPLACE TABLE
  `saml-d-aml-monitoring.aml_monitoring.raw_transactions`
AS

SELECT *
FROM
  `saml-d-aml-monitoring.aml_monitoring.ext_saml_d`;
```

## Validação obrigatória da raw

```sql
SELECT COUNT(*) AS total_rows
FROM `saml-d-aml-monitoring.aml_monitoring.raw_transactions`;
```

Resultado:

```text
9.504.852
```

Não avance se o total for diferente.

---

# 8. Perfil completo esperado

Depois da staging, o perfil deve ser:

```text
Total de transações:                9.504.852
Transações ilícitas:                    9.873
Transações normais:                 9.494.979
Taxa de lavagem:                     0,103873%
Primeira data:                      2022-10-07
Última data:                        2023-08-23
Período:                                  321 dias
Remetentes distintos:                  292.715
Destinatários distintos:               652.266
Contas únicas:                          855.460
Pares remetente-destinatário:           887.497
Moedas de pagamento:                         13
Moedas de recebimento:                       13
Localizações de origem:                      18
Localizações de destino:                     18
Tipos de pagamento:                           7
Padrões transacionais:                       28
Duplicatas exatas:                            0
```

## Consulta de perfil

```sql
WITH main_profile AS (
  SELECT
    COUNT(*) AS total_transactions,
    COUNTIF(is_laundering = 1) AS laundering_transactions,
    MIN(transaction_date) AS first_transaction_date,
    MAX(transaction_date) AS last_transaction_date,
    COUNT(DISTINCT sender_account) AS distinct_sender_accounts,
    COUNT(DISTINCT receiver_account) AS distinct_receiver_accounts,
    COUNT(DISTINCT payment_currency) AS distinct_payment_currencies,
    COUNT(DISTINCT received_currency) AS distinct_received_currencies,
    COUNT(DISTINCT sender_bank_location) AS distinct_sender_locations,
    COUNT(DISTINCT receiver_bank_location) AS distinct_receiver_locations,
    COUNT(DISTINCT payment_type) AS distinct_payment_types,
    COUNT(DISTINCT transaction_pattern) AS distinct_transaction_patterns
  FROM
    `saml-d-aml-monitoring.aml_monitoring.stg_transactions`
),

distinct_pairs AS (
  SELECT COUNT(*) AS distinct_sender_receiver_pairs
  FROM (
    SELECT sender_account, receiver_account
    FROM `saml-d-aml-monitoring.aml_monitoring.stg_transactions`
    GROUP BY sender_account, receiver_account
  )
),

distinct_accounts AS (
  SELECT COUNT(*) AS total_distinct_accounts
  FROM (
    SELECT sender_account AS account
    FROM `saml-d-aml-monitoring.aml_monitoring.stg_transactions`

    UNION DISTINCT

    SELECT receiver_account AS account
    FROM `saml-d-aml-monitoring.aml_monitoring.stg_transactions`
  )
)

SELECT
  main_profile.total_transactions,
  main_profile.laundering_transactions,

  ROUND(
    SAFE_DIVIDE(
      main_profile.laundering_transactions,
      main_profile.total_transactions
    ) * 100,
    6
  ) AS laundering_percentage,

  main_profile.first_transaction_date,
  main_profile.last_transaction_date,

  DATE_DIFF(
    main_profile.last_transaction_date,
    main_profile.first_transaction_date,
    DAY
  ) + 1 AS dataset_period_days,

  main_profile.distinct_sender_accounts,
  main_profile.distinct_receiver_accounts,
  distinct_accounts.total_distinct_accounts,
  distinct_pairs.distinct_sender_receiver_pairs,
  main_profile.distinct_payment_currencies,
  main_profile.distinct_received_currencies,
  main_profile.distinct_sender_locations,
  main_profile.distinct_receiver_locations,
  main_profile.distinct_payment_types,
  main_profile.distinct_transaction_patterns

FROM main_profile
CROSS JOIN distinct_pairs
CROSS JOIN distinct_accounts;
```

---

# 9. Regras críticas do projeto

## Contas

As contas permanecem como `STRING`.

Não:

- converter para número;
- remover caracteres;
- completar com zeros;
- realizar cálculos matemáticos.

## Moedas

As análises de valor devem separar `payment_currency`.

O dataset não possui conversão cambial.

As regras não somam moedas diferentes, mas usam os mesmos limiares numéricos para cada moeda. Isso é uma limitação do MVP.

## Labels

Não usar:

```text
is_laundering
transaction_pattern
```

dentro das regras.

As labels entram apenas em `rule_evaluation`.

## Janelas

Usar:

```sql
DATE_TRUNC(transaction_date, WEEK(MONDAY))
```

Não mudar para dia, mês ou semana iniciada no domingo.

## Limiares

Os limiares são exploratórios e específicos para este dataset.

Eles não são limites regulatórios oficiais.

---

# 10. Ordem de execução

Executar exatamente nesta ordem:

```text
01_staging_view.sql
02_rule_structuring.sql
03_rule_smurfing.sql
04_alerts_view.sql
05_rule_evaluation.sql
06_dashboard_summary.sql
```

---

# 11. SQLs completos

## `01_staging_view.sql`

```sql
-- =============================================================================
-- ARQUIVO: 01_staging_view.sql
-- OBJETIVO:
--   Converter a tabela bruta, cujos campos estão em STRING, em uma view com
--   tipos adequados para análise.
--
-- ENTRADA:
--   `saml-d-aml-monitoring.aml_monitoring.raw_transactions`
--
-- SAÍDA:
--   `saml-d-aml-monitoring.aml_monitoring.stg_transactions`
--
-- COMO EXPLICAR:
--   "A raw preserva os dados originais. A staging limpa textos e converte
--   datas, horários, valores e labels para os tipos corretos."
--
-- CONCEITOS:
--   TRIM      -> remove espaços externos.
--   SAFE_CAST -> tenta converter; em caso de valor inválido, devolve NULL.
--   STRING    -> contas são identificadores, não valores matemáticos.
-- =============================================================================

CREATE OR REPLACE VIEW
  `saml-d-aml-monitoring.aml_monitoring.stg_transactions`
AS

SELECT
  SAFE_CAST(TRIM(date_raw) AS DATE) AS transaction_date,
  SAFE_CAST(TRIM(time_raw) AS TIME) AS transaction_time,

  SAFE_CAST(
    CONCAT(TRIM(date_raw), ' ', TRIM(time_raw))
    AS DATETIME
  ) AS transaction_datetime,

  TRIM(sender_account_raw) AS sender_account,
  TRIM(receiver_account_raw) AS receiver_account,

  SAFE_CAST(TRIM(amount_raw) AS NUMERIC) AS amount,

  TRIM(payment_currency_raw) AS payment_currency,
  TRIM(received_currency_raw) AS received_currency,
  TRIM(sender_bank_location_raw) AS sender_bank_location,
  TRIM(receiver_bank_location_raw) AS receiver_bank_location,
  TRIM(payment_type_raw) AS payment_type,

  -- Labels: usadas somente na avaliação, nunca nas regras.
  SAFE_CAST(TRIM(is_laundering_raw) AS INT64) AS is_laundering,
  TRIM(laundering_type_raw) AS transaction_pattern

FROM
  `saml-d-aml-monitoring.aml_monitoring.raw_transactions`;


-- VALIDAÇÃO
-- Esperado: 9.504.852 registros e zero nulos nos campos principais.
SELECT
  COUNT(*) AS total_transactions,
  COUNTIF(transaction_date IS NULL) AS null_transaction_date,
  COUNTIF(transaction_time IS NULL) AS null_transaction_time,
  COUNTIF(transaction_datetime IS NULL) AS null_transaction_datetime,
  COUNTIF(amount IS NULL) AS null_amount,
  COUNTIF(is_laundering IS NULL) AS null_is_laundering
FROM
  `saml-d-aml-monitoring.aml_monitoring.stg_transactions`;
```
## `02_rule_structuring.sql`

```sql
-- =============================================================================
-- ARQUIVO: 02_rule_structuring.sql
-- OBJETIVO:
--   Detectar recebimentos fragmentados de múltiplos remetentes para uma mesma
--   conta durante uma semana.
--
-- ENTRADA: stg_transactions
-- SAÍDA:   rule_structuring
--
-- UNIDADE DO ALERTA:
--   receiver_account + semana + payment_currency
--
-- COMO EXPLICAR:
--   "Agrupei por destinatário, semana e moeda. Depois medi quantidade de
--   transações, remetentes distintos, total acumulado e maior valor individual."
--
-- IMPORTANTE:
--   is_laundering e transaction_pattern não aparecem na regra.
-- =============================================================================

CREATE OR REPLACE VIEW
  `saml-d-aml-monitoring.aml_monitoring.rule_structuring`
AS

WITH receiver_weekly_activity AS (
  SELECT
    receiver_account,

    DATE_TRUNC(
      transaction_date,
      WEEK(MONDAY)
    ) AS period_start,

    -- Evita somar moedas diferentes.
    payment_currency,

    COUNT(*) AS transaction_count,
    COUNT(DISTINCT sender_account) AS distinct_senders,

    SUM(amount) AS total_amount,
    AVG(amount) AS average_amount,
    MIN(amount) AS min_individual_amount,
    MAX(amount) AS max_individual_amount,

    MIN(transaction_datetime) AS first_transaction_datetime,
    MAX(transaction_datetime) AS last_transaction_datetime

  FROM
    `saml-d-aml-monitoring.aml_monitoring.stg_transactions`

  WHERE
    amount > 0

  GROUP BY
    receiver_account,
    DATE_TRUNC(transaction_date, WEEK(MONDAY)),
    payment_currency
)

SELECT
  CONCAT(
    'STRUCTURING_',
    receiver_account,
    '_',
    CAST(period_start AS STRING),
    '_',
    REPLACE(payment_currency, ' ', '_')
  ) AS alert_id,

  'STRUCTURING' AS rule_name,
  receiver_account AS alerted_account,

  period_start,
  DATE_ADD(period_start, INTERVAL 6 DAY) AS period_end,

  payment_currency,
  transaction_count,
  distinct_senders,

  total_amount,
  average_amount,
  min_individual_amount,
  max_individual_amount,

  first_transaction_datetime,
  last_transaction_datetime,

  'Recebimento semanal fragmentado de múltiplos remetentes'
    AS alert_reason

FROM
  receiver_weekly_activity

WHERE
  -- Limiares exploratórios, não regulatórios.
  transaction_count >= 3
  AND distinct_senders >= 3
  AND total_amount >= 10000
  AND max_individual_amount <= 10000;


-- VALIDAÇÃO
-- Esperado: 8.754 alertas agregados.
SELECT
  COUNT(*) AS total_alerts
FROM
  `saml-d-aml-monitoring.aml_monitoring.rule_structuring`;
```
## `03_rule_smurfing.sql`

```sql
-- =============================================================================
-- ARQUIVO: 03_rule_smurfing.sql
-- OBJETIVO:
--   Detectar operações pequenas e recorrentes entre o mesmo remetente e
--   destinatário, distribuídas por vários dias da semana.
--
-- ENTRADA: stg_transactions
-- SAÍDA:   rule_smurfing
--
-- UNIDADE DO ALERTA:
--   sender_account + receiver_account + semana + payment_currency
--
-- COMO EXPLICAR:
--   "A regra mede recorrência entre o mesmo par. Os campos active_days e
--   activity_span_hours ajudam a distinguir atividade espalhada ao longo da
--   semana de grandes lotes legítimos concentrados em um único dia."
-- =============================================================================

CREATE OR REPLACE VIEW
  `saml-d-aml-monitoring.aml_monitoring.rule_smurfing`
AS

WITH pair_weekly_activity AS (
  SELECT
    sender_account,
    receiver_account,

    DATE_TRUNC(
      transaction_date,
      WEEK(MONDAY)
    ) AS period_start,

    payment_currency,

    COUNT(*) AS transaction_count,
    COUNT(DISTINCT transaction_date) AS active_days,

    SUM(amount) AS total_amount,
    AVG(amount) AS average_amount,
    MIN(amount) AS min_individual_amount,
    MAX(amount) AS max_individual_amount,

    MIN(transaction_datetime) AS first_transaction_datetime,
    MAX(transaction_datetime) AS last_transaction_datetime,

    DATETIME_DIFF(
      MAX(transaction_datetime),
      MIN(transaction_datetime),
      HOUR
    ) AS activity_span_hours

  FROM
    `saml-d-aml-monitoring.aml_monitoring.stg_transactions`

  WHERE
    amount > 0

  GROUP BY
    sender_account,
    receiver_account,
    DATE_TRUNC(transaction_date, WEEK(MONDAY)),
    payment_currency
)

SELECT
  CONCAT(
    'SMURFING_',
    sender_account,
    '_',
    receiver_account,
    '_',
    CAST(period_start AS STRING),
    '_',
    REPLACE(payment_currency, ' ', '_')
  ) AS alert_id,

  'SMURFING' AS rule_name,

  receiver_account AS alerted_account,
  sender_account AS related_account,

  period_start,
  DATE_ADD(period_start, INTERVAL 6 DAY) AS period_end,

  payment_currency,

  transaction_count,
  active_days,
  activity_span_hours,

  total_amount,
  average_amount,
  min_individual_amount,
  max_individual_amount,

  first_transaction_datetime,
  last_transaction_datetime,

  'Operações fragmentadas e recorrentes entre o mesmo par durante a semana'
    AS alert_reason

FROM
  pair_weekly_activity

WHERE
  -- Limiares exploratórios, não regulatórios.
  transaction_count BETWEEN 3 AND 8
  AND active_days >= 3
  AND total_amount BETWEEN 6000 AND 25000
  AND average_amount <= 4000
  AND max_individual_amount <= 5000
  AND activity_span_hours >= 48;


-- VALIDAÇÃO
-- Esperado: 13.701 alertas agregados.
SELECT
  COUNT(*) AS total_alerts
FROM
  `saml-d-aml-monitoring.aml_monitoring.rule_smurfing`;
```
## `04_alerts_view.sql`

```sql
-- =============================================================================
-- ARQUIVO: 04_alerts_view.sql
-- OBJETIVO:
--   Unificar os alertas das duas regras em uma única estrutura.
--
-- ENTRADAS:
--   rule_structuring
--   rule_smurfing
--
-- SAÍDA:
--   alerts
--
-- COMO EXPLICAR:
--   "Usei UNION ALL para empilhar as duas filas. Como cada regra possui alguns
--   campos exclusivos, usei NULL tipado onde o campo não se aplica."
--
-- POR QUE UNION ALL?
--   Mantém todas as linhas e não gasta processamento tentando remover duplicatas.
-- =============================================================================

CREATE OR REPLACE VIEW
  `saml-d-aml-monitoring.aml_monitoring.alerts`
AS

SELECT
  alert_id,
  rule_name,
  alerted_account,

  CAST(NULL AS STRING) AS related_account,

  period_start,
  period_end,
  payment_currency,

  transaction_count,
  distinct_senders,

  CAST(NULL AS INT64) AS active_days,
  CAST(NULL AS INT64) AS activity_span_hours,

  total_amount,
  average_amount,
  min_individual_amount,
  max_individual_amount,

  first_transaction_datetime,
  last_transaction_datetime,

  alert_reason

FROM
  `saml-d-aml-monitoring.aml_monitoring.rule_structuring`

UNION ALL

SELECT
  alert_id,
  rule_name,
  alerted_account,
  related_account,

  period_start,
  period_end,
  payment_currency,

  transaction_count,

  CAST(NULL AS INT64) AS distinct_senders,

  active_days,
  activity_span_hours,

  total_amount,
  average_amount,
  min_individual_amount,
  max_individual_amount,

  first_transaction_datetime,
  last_transaction_datetime,

  alert_reason

FROM
  `saml-d-aml-monitoring.aml_monitoring.rule_smurfing`;


-- VALIDAÇÃO
-- Esperado:
--   SMURFING    = 13.701
--   STRUCTURING =  8.754
--   TOTAL       = 22.455
SELECT
  rule_name,
  COUNT(*) AS total_alerts
FROM
  `saml-d-aml-monitoring.aml_monitoring.alerts`
GROUP BY
  rule_name
ORDER BY
  rule_name;
```
## `05_rule_evaluation.sql`

```sql
-- =============================================================================
-- ARQUIVO: 05_rule_evaluation.sql
-- OBJETIVO:
--   Comparar os alertas com as labels e calcular as métricas finais.
--
-- ENTRADAS:
--   stg_transactions
--   rule_structuring
--   rule_smurfing
--
-- SAÍDA:
--   rule_evaluation
--
-- COMO EXPLICAR:
--   "Parti de todas as transações e usei LEFT JOIN para marcar quais pertenciam
--   a grupos alertados. Depois comparei essa flag com is_laundering."
--
-- TARGET LEAKAGE:
--   As labels aparecem somente nesta etapa, depois de os alertas existirem.
-- =============================================================================

CREATE OR REPLACE VIEW
  `saml-d-aml-monitoring.aml_monitoring.rule_evaluation`
AS

WITH transaction_flags AS (
  SELECT
    t.is_laundering,
    t.transaction_pattern,

    CASE
      WHEN structuring.alert_id IS NOT NULL THEN 1
      ELSE 0
    END AS structuring_alerted,

    CASE
      WHEN smurfing.alert_id IS NOT NULL THEN 1
      ELSE 0
    END AS smurfing_alerted

  FROM
    `saml-d-aml-monitoring.aml_monitoring.stg_transactions` AS t

  LEFT JOIN
    `saml-d-aml-monitoring.aml_monitoring.rule_structuring`
      AS structuring
    ON t.receiver_account = structuring.alerted_account
    AND DATE_TRUNC(
      t.transaction_date,
      WEEK(MONDAY)
    ) = structuring.period_start
    AND t.payment_currency = structuring.payment_currency

  LEFT JOIN
    `saml-d-aml-monitoring.aml_monitoring.rule_smurfing`
      AS smurfing
    ON t.sender_account = smurfing.related_account
    AND t.receiver_account = smurfing.alerted_account
    AND DATE_TRUNC(
      t.transaction_date,
      WEEK(MONDAY)
    ) = smurfing.period_start
    AND t.payment_currency = smurfing.payment_currency
),

rule_flags AS (
  SELECT
    'STRUCTURING' AS rule_name,
    is_laundering,
    structuring_alerted AS is_alerted
  FROM
    transaction_flags

  UNION ALL

  SELECT
    'SMURFING' AS rule_name,
    is_laundering,
    smurfing_alerted AS is_alerted
  FROM
    transaction_flags

  UNION ALL

  SELECT
    'ALL_RULES' AS rule_name,
    is_laundering,

    CASE
      WHEN structuring_alerted = 1
        OR smurfing_alerted = 1
      THEN 1
      ELSE 0
    END AS is_alerted

  FROM
    transaction_flags
),

metrics AS (
  SELECT
    rule_name,

    COUNT(*) AS total_transactions,

    -- Alertada e ilícita.
    COUNTIF(
      is_alerted = 1
      AND is_laundering = 1
    ) AS true_positives,

    -- Alertada e normal.
    COUNTIF(
      is_alerted = 1
      AND is_laundering = 0
    ) AS false_positives,

    -- Não alertada e ilícita.
    COUNTIF(
      is_alerted = 0
      AND is_laundering = 1
    ) AS false_negatives,

    -- Não alertada e normal.
    COUNTIF(
      is_alerted = 0
      AND is_laundering = 0
    ) AS true_negatives,

    COUNTIF(is_alerted = 1) AS alerted_transactions

  FROM
    rule_flags

  GROUP BY
    rule_name
)

SELECT
  rule_name,
  total_transactions,
  alerted_transactions,

  true_positives,
  false_positives,
  false_negatives,
  true_negatives,

  -- Dos alertados, quantos eram ilícitos?
  SAFE_DIVIDE(
    true_positives,
    true_positives + false_positives
  ) AS precision,

  -- Dos ilícitos, quantos foram encontrados?
  SAFE_DIVIDE(
    true_positives,
    true_positives + false_negatives
  ) AS recall,

  -- Média harmônica entre precision e recall.
  SAFE_DIVIDE(
    2 * true_positives,
    2 * true_positives
      + false_positives
      + false_negatives
  ) AS f1_score,

  -- Percentual da base enviado à fila de análise.
  SAFE_DIVIDE(
    alerted_transactions,
    total_transactions
  ) AS alert_rate

FROM
  metrics;


-- VALIDAÇÃO
-- Resultados esperados:
-- STRUCTURING: TP 1.141 | Precision 1,3110% | Recall 11,5568%
-- SMURFING:    TP   536 | Precision 1,1321% | Recall  5,4289%
-- ALL_RULES:   TP 1.677 | Precision 1,3054% | Recall 16,9857%
SELECT
  rule_name,
  total_transactions,
  alerted_transactions,
  true_positives,
  false_positives,
  false_negatives,
  true_negatives,

  ROUND(precision * 100, 4) AS precision_pct,
  ROUND(recall * 100, 4) AS recall_pct,
  ROUND(f1_score * 100, 4) AS f1_score_pct,
  ROUND(alert_rate * 100, 4) AS alert_rate_pct

FROM
  `saml-d-aml-monitoring.aml_monitoring.rule_evaluation`

ORDER BY
  CASE rule_name
    WHEN 'STRUCTURING' THEN 1
    WHEN 'SMURFING' THEN 2
    WHEN 'ALL_RULES' THEN 3
  END;
```
## `06_dashboard_summary.sql`

```sql
-- =============================================================================
-- ARQUIVO: 06_dashboard_summary.sql
-- OBJETIVO:
--   Preparar uma fonte pequena e pronta para os scorecards do Looker Studio.
--
-- ENTRADAS:
--   alerts
--   rule_evaluation
--
-- SAÍDA:
--   dashboard_summary
--
-- DIFERENÇA ESSENCIAL:
--   total_alerts         = grupos agregados gerados pelas regras.
--   alerted_transactions = transações individuais dentro desses grupos.
-- =============================================================================

CREATE OR REPLACE VIEW
  `saml-d-aml-monitoring.aml_monitoring.dashboard_summary`
AS

WITH alert_counts AS (
  SELECT
    rule_name,
    COUNT(*) AS total_alerts
  FROM
    `saml-d-aml-monitoring.aml_monitoring.alerts`
  GROUP BY
    rule_name

  UNION ALL

  SELECT
    'ALL_RULES' AS rule_name,
    COUNT(*) AS total_alerts
  FROM
    `saml-d-aml-monitoring.aml_monitoring.alerts`
)

SELECT
  evaluation.rule_name,

  alert_counts.total_alerts,

  evaluation.total_transactions,

  evaluation.true_positives
    + evaluation.false_negatives
    AS total_illicit_transactions,

  evaluation.total_transactions
    - evaluation.true_positives
    - evaluation.false_negatives
    AS total_normal_transactions,

  evaluation.alerted_transactions,

  evaluation.true_positives,
  evaluation.false_positives,
  evaluation.false_negatives,
  evaluation.true_negatives,

  evaluation.precision,
  evaluation.recall,
  evaluation.f1_score,
  evaluation.alert_rate,

  -- Prevalência de lavagem na base.
  SAFE_DIVIDE(
    evaluation.true_positives
      + evaluation.false_negatives,
    evaluation.total_transactions
  ) AS dataset_laundering_rate,

  -- Quantas vezes a fila é mais concentrada em lavagem.
  SAFE_DIVIDE(
    evaluation.precision,
    SAFE_DIVIDE(
      evaluation.true_positives
        + evaluation.false_negatives,
      evaluation.total_transactions
    )
  ) AS precision_lift

FROM
  `saml-d-aml-monitoring.aml_monitoring.rule_evaluation`
    AS evaluation

LEFT JOIN
  alert_counts
USING (rule_name);


-- VALIDAÇÃO
-- ALL_RULES esperado:
-- total_alerts         = 22.455
-- alerted_transactions = 128.463
-- true_positives       = 1.677
-- precision            = 1,3054%
-- recall               = 16,9857%
-- f1_score             = 2,4245%
-- alert_rate           = 1,3516%
-- precision_lift       = 12,57x
SELECT
  rule_name,
  total_alerts,
  total_transactions,
  total_illicit_transactions,
  alerted_transactions,
  true_positives,
  false_positives,
  false_negatives,

  ROUND(precision * 100, 4) AS precision_pct,
  ROUND(recall * 100, 4) AS recall_pct,
  ROUND(f1_score * 100, 4) AS f1_score_pct,
  ROUND(alert_rate * 100, 4) AS alert_rate_pct,
  ROUND(dataset_laundering_rate * 100, 4)
    AS dataset_laundering_rate_pct,
  ROUND(precision_lift, 2) AS precision_lift

FROM
  `saml-d-aml-monitoring.aml_monitoring.dashboard_summary`

ORDER BY
  CASE rule_name
    WHEN 'STRUCTURING' THEN 1
    WHEN 'SMURFING' THEN 2
    WHEN 'ALL_RULES' THEN 3
  END;
```

---

# 12. Resultados finais esperados

## Alertas agregados

```text
STRUCTURING:  8.754
SMURFING:    13.701
TOTAL:       22.455
```

## Avaliação das regras

| Métrica | Structuring | Smurfing | ALL_RULES |
|---|---:|---:|---:|
| Total de transações | 9.504.852 | 9.504.852 | 9.504.852 |
| Transações alertadas | 87.030 | 47.344 | 128.463 |
| True positives | 1.141 | 536 | 1.677 |
| False positives | 85.889 | 46.808 | 126.786 |
| False negatives | 8.732 | 9.337 | 8.196 |
| True negatives | 9.409.090 | 9.448.171 | 9.368.193 |
| Precision | 1,3110% | 1,1321% | 1,3054% |
| Recall | 11,5568% | 5,4289% | 16,9857% |
| F1-score | 2,3549% | 1,8736% | 2,4245% |
| Alert rate | 0,9156% | 0,4981% | 1,3516% |
| Precision lift | 12,62x | 10,90x | 12,57x |

## Recalls específicos conhecidos

```text
Structuring:
1.025 de 1.870 transações
Recall específico: 54,81%

Smurfing:
536 de 932 transações
Recall específico: 57,51%
```

## Interpretação

A base completa possui aproximadamente:

```text
0,1039% de lavagem
```

A fila combinada possui:

```text
1,3054% de precision
```

Assim, a fila concentra lavagem aproximadamente:

```text
12,57 vezes mais
```

As regras não confirmam lavagem. Elas priorizam casos para investigação humana.

---

# 13. Como validar cada etapa

## Staging

Esperado:

```text
9.504.852 registros
0 datas nulas
0 horários nulos
0 datetimes nulos
0 valores nulos
0 labels nulas
0 duplicatas exatas
```

## Structuring

```sql
SELECT COUNT(*) AS total_alerts
FROM `saml-d-aml-monitoring.aml_monitoring.rule_structuring`;
```

Esperado:

```text
8.754
```

## Smurfing

```sql
SELECT COUNT(*) AS total_alerts
FROM `saml-d-aml-monitoring.aml_monitoring.rule_smurfing`;
```

Esperado:

```text
13.701
```

## Alerts

```sql
SELECT
  rule_name,
  COUNT(*) AS total_alerts
FROM
  `saml-d-aml-monitoring.aml_monitoring.alerts`
GROUP BY
  rule_name;
```

Esperado:

```text
STRUCTURING  8.754
SMURFING    13.701
```

## Evaluation

```sql
SELECT *
FROM `saml-d-aml-monitoring.aml_monitoring.rule_evaluation`;
```

Esperado: três linhas.

```text
STRUCTURING
SMURFING
ALL_RULES
```

## Dashboard summary

```sql
SELECT *
FROM `saml-d-aml-monitoring.aml_monitoring.dashboard_summary`;
```

Esperado: três linhas com os valores finais.

---

# 14. Looker Studio

## Fontes

Adicionar:

```text
saml-d-aml-monitoring.aml_monitoring.dashboard_summary
saml-d-aml-monitoring.aml_monitoring.alerts
```

## Cards consolidados

Fonte:

```text
dashboard_summary
```

Aplicar em cada card:

```text
Filtro: rule_name = ALL_RULES
Agregação: MAX
```

Cards:

| Card | Campo | Resultado |
|---|---|---:|
| Total de transações | total_transactions | 9.504.852 |
| Transações ilícitas | total_illicit_transactions | 9.873 |
| Alertas | total_alerts | 22.455 |
| Transações alertadas | alerted_transactions | 128.463 |
| Alert rate | alert_rate | 1,35% |
| Precision lift | precision_lift | 12,57x |
| Precision | precision | 1,31% |
| Recall | recall | 16,99% |
| F1-score | f1_score | 2,42% |

Percentuais devem ser formatados como percentual.

## Gráfico: alertas por regra

Fonte:

```text
alerts
```

Configuração:

```text
Dimensão: rule_name
Métrica: COUNT_DISTINCT(alert_id)
```

Resultados:

```text
STRUCTURING  8.754
SMURFING    13.701
```

## Gráfico: Top 10 contas

Fonte:

```text
alerts
```

Configuração:

```text
Dimensão: alerted_account
Métrica: COUNT_DISTINCT(alert_id)
Ordenação: decrescente
Número máximo: 10
```

Desativar:

```text
Agrupar o restante como Outros
```

## Tabela detalhada

Campos recomendados:

```text
rule_name
alerted_account
related_account
period_start
period_end
payment_currency
alert_reason
transaction_count
total_amount
average_amount
max_individual_amount
```

Ordenar por:

```text
total_amount decrescente
```

## Filtro por regra

Criar um controle dropdown:

```text
Fonte: alerts
Campo: rule_name
Estado inicial: Selecionar tudo
```

Esse filtro deve alterar:

- alertas por regra;
- Top 10 contas;
- tabela detalhada.

Ele não deve alterar os cards consolidados, que possuem fonte e filtro próprios.

---

# 15. Erros comuns

## Erro: Alert rate aparece como 2,77%

Causa:

O Looker Studio somou:

```text
STRUCTURING
SMURFING
ALL_RULES
```

Correção:

```text
Filtro: rule_name = ALL_RULES
Agregação: MAX
```

## Erro: gráfico tem uma barra enorme chamada “Outros”

Causa:

O Looker Studio agrupou as demais contas.

Correção:

```text
Desativar “Agrupar o restante como Outros”
```

## Erro: total combinado é a soma das transações alertadas

Não somar:

```text
87.030 + 47.344
```

porque existe sobreposição entre as regras.

O valor correto combinado é calculado com `OR`:

```text
128.463
```

## Erro: `01_staging_view.sql` não reconhece as colunas

Verificar o esquema da `raw_transactions`.

A view espera:

```text
date_raw
time_raw
sender_account_raw
receiver_account_raw
amount_raw
payment_currency_raw
received_currency_raw
sender_bank_location_raw
receiver_bank_location_raw
payment_type_raw
is_laundering_raw
laundering_type_raw
```

Corrigir somente o mapeamento da raw ou os aliases da staging. Não alterar as regras.

## Erro: contagem de Structuring diferente

Confirmar:

```text
receiver_account
WEEK(MONDAY)
payment_currency
transaction_count >= 3
distinct_senders >= 3
total_amount >= 10000
max_individual_amount <= 10000
amount > 0
```

## Erro: contagem de Smurfing diferente

Confirmar:

```text
sender_account
receiver_account
WEEK(MONDAY)
payment_currency
transaction_count BETWEEN 3 AND 8
active_days >= 3
total_amount BETWEEN 6000 AND 25000
average_amount <= 4000
max_individual_amount <= 5000
activity_span_hours >= 48
amount > 0
```

## Erro: precision e recall não coincidem

Confirmar:

- labels somente na avaliação;
- `LEFT JOIN`;
- moeda incluída no join;
- semana iniciada na segunda;
- par remetente-destinatário no Smurfing;
- combinação `ALL_RULES` feita com `OR`.

---

# 16. Explicações simples das métricas

## Precision

Entre as transações alertadas, quantas eram ilícitas?

```text
TP / (TP + FP)
```

No combinado:

```text
1.677 / 128.463 = 1,3054%
```

## Recall

Entre todas as transações ilícitas, quantas foram encontradas?

```text
TP / (TP + FN)
```

No combinado:

```text
1.677 / 9.873 = 16,9857%
```

## Alert rate

Qual percentual da base foi enviado para investigação?

```text
128.463 / 9.504.852 = 1,3516%
```

## Precision lift

Quantas vezes a fila é mais concentrada em lavagem do que a base?

```text
1,3054% / 0,1039% = 12,57x
```

## Por que não usar accuracy

A base possui aproximadamente 99,90% de transações normais.

Classificar tudo como normal geraria alta accuracy, mas zero detecção de lavagem.

---

# 17. Como explicar as regras

## Structuring

> Agrupei as entradas por destinatário, semana e moeda. A regra procura pelo menos três transações vindas de pelo menos três remetentes, acumulando um valor relevante, sem uma operação individual muito alta.

## Smurfing

> Agrupei as transações pelo mesmo remetente e destinatário, semana e moeda. A regra procura operações pequenas e recorrentes em pelo menos três dias, distribuídas por pelo menos 48 horas.

## Target leakage

> As labels representam a resposta correta. Elas não foram usadas para criar as regras; foram usadas somente para avaliar os alertas depois.

## Uso de IA

> Claude Code e IA generativa foram usados para revisar consultas, organizar o repositório e melhorar a documentação. As consultas foram executadas no BigQuery e as decisões finais foram validadas pelo responsável pelo projeto.

---

# 18. Limitações

- dataset sintético;
- ausência de KYC;
- ausência de valor normalizado por câmbio;
- mesmos limiares aplicados a moedas diferentes;
- limiares calibrados para esta base;
- muitos falsos positivos;
- ausência de baseline por conta;
- ausência de análise de redes com múltiplos saltos;
- ausência de atualização automática;
- notebook Python baseado em 10.000 linhas iniciais.

Versão simples para o README:

> O dataset não tem conversão de moedas. Por isso, as regras analisam cada moeda separadamente. Mesmo assim, os mesmos limites são usados para moedas diferentes, o que precisaria ser ajustado em um sistema real. As regras também não consideram o perfil de cada conta nem transferências em cadeia.

---

# 19. Próximos passos

Versão simples:

> Como próximos passos, o projeto poderia considerar o comportamento normal de cada conta, ajustar os valores entre moedas diferentes e tornar os limites das regras mais fáceis de testar. Também seria possível identificar redes de contas suspeitas, automatizar a execução e criar alertas. A IA poderia ajudar a resumir os casos para o analista, mas não decidir quais transações devem ser alertadas.

---

# 20. Checklist final de reprodução

Antes de considerar o projeto reproduzido:

- [ ] O CSV é a versão completa do SAML-D.
- [ ] `raw_transactions` possui 9.504.852 registros.
- [ ] Todas as colunas da raw estão como STRING.
- [ ] A staging possui 9.504.852 registros.
- [ ] Não há nulos nos campos principais.
- [ ] Não há duplicatas exatas.
- [ ] Structuring possui 8.754 alertas.
- [ ] Smurfing possui 13.701 alertas.
- [ ] Alerts possui 22.455 linhas.
- [ ] ALL_RULES possui 128.463 transações alertadas.
- [ ] ALL_RULES possui 1.677 true positives.
- [ ] Precision é 1,3054%.
- [ ] Recall é 16,9857%.
- [ ] F1 é 2,4245%.
- [ ] Alert rate é 1,3516%.
- [ ] Precision lift é 12,57x.
- [ ] Os cards usam `rule_name = ALL_RULES`.
- [ ] Os cards usam agregação `MAX`.
- [ ] O dropdown inicia em “Selecionar tudo”.
- [ ] As labels não aparecem nas regras.
- [ ] Nenhum limiar é apresentado como regulatório.

---

# 21. Prompt pronto para outra IA

Copie o texto abaixo junto com este arquivo:

```text
Estou continuando um projeto AML Transaction Monitoring com SAML-D.

Leia integralmente o arquivo GUIA_REPRODUCAO.MD antes de responder.

Use o guia como fonte de verdade para:
- ambiente;
- tabelas;
- regras;
- SQLs;
- métricas;
- dashboard;
- resultados esperados.

Não altere os limiares antes de reproduzir os números.
Não use is_laundering ou transaction_pattern dentro das regras.
Mantenha as contas como STRING.
Separe as análises por payment_currency.
Trabalhe uma etapa por vez.
Depois de fornecer uma consulta, explique:
1. entrada;
2. transformação;
3. saída;
4. resultado esperado;
5. como validar.

Se um resultado divergir, investigue a causa em vez de inventar números.
```

---

# 22. Resumo final

```text
Projeto: saml-d-aml-monitoring
Dataset: aml_monitoring
Base: 9.504.852 transações
Ilícitas: 9.873
Regras: Structuring e Smurfing
Alertas: 22.455
Transações alertadas: 128.463
True positives: 1.677
Precision: 1,3054%
Recall: 16,9857%
F1: 2,4245%
Alert rate: 1,3516%
Precision lift: 12,57x
```

Este documento deve ser preservado mesmo que a conversa seja apagada.
