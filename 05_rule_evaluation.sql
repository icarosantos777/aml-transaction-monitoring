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
