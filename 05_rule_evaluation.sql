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
    `saml-d-aml-monitoring.aml_monitoring.rule_structuring` AS structuring
    ON t.receiver_account = structuring.alerted_account
    AND DATE_TRUNC(t.transaction_date, WEEK(MONDAY)) = structuring.period_start
    AND t.payment_currency = structuring.payment_currency

  LEFT JOIN
    `saml-d-aml-monitoring.aml_monitoring.rule_smurfing` AS smurfing
    ON t.sender_account = smurfing.related_account
    AND t.receiver_account = smurfing.alerted_account
    AND DATE_TRUNC(t.transaction_date, WEEK(MONDAY)) = smurfing.period_start
    AND t.payment_currency = smurfing.payment_currency
),

rule_flags AS (
  SELECT
    'STRUCTURING' AS rule_name,
    is_laundering,
    structuring_alerted AS is_alerted
  FROM transaction_flags

  UNION ALL

  SELECT
    'SMURFING' AS rule_name,
    is_laundering,
    smurfing_alerted AS is_alerted
  FROM transaction_flags

  UNION ALL

  SELECT
    'ALL_RULES' AS rule_name,
    is_laundering,
    CASE
      WHEN structuring_alerted = 1 OR smurfing_alerted = 1 THEN 1
      ELSE 0
    END AS is_alerted
  FROM transaction_flags
),

metrics AS (
  SELECT
    rule_name,
    COUNT(*) AS total_transactions,

    COUNTIF(is_alerted = 1 AND is_laundering = 1) AS true_positives,
    COUNTIF(is_alerted = 1 AND is_laundering = 0) AS false_positives,
    COUNTIF(is_alerted = 0 AND is_laundering = 1) AS false_negatives,
    COUNTIF(is_alerted = 0 AND is_laundering = 0) AS true_negatives,

    COUNTIF(is_alerted = 1) AS alerted_transactions
  FROM rule_flags
  GROUP BY rule_name
)

SELECT
  rule_name,
  total_transactions,
  alerted_transactions,

  true_positives,
  false_positives,
  false_negatives,
  true_negatives,

  SAFE_DIVIDE(true_positives, true_positives + false_positives) AS precision,
  SAFE_DIVIDE(true_positives, true_positives + false_negatives) AS recall,
  SAFE_DIVIDE(2 * true_positives, 2 * true_positives + false_positives + false_negatives) AS f1_score,
  SAFE_DIVIDE(alerted_transactions, total_transactions) AS alert_rate

FROM metrics;


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
