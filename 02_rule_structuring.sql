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
