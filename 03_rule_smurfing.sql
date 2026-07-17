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
  transaction_count BETWEEN 3 AND 8
  AND active_days >= 3
  AND total_amount BETWEEN 6000 AND 25000
  AND average_amount <= 4000
  AND max_individual_amount <= 5000
  AND activity_span_hours >= 48;


SELECT
  COUNT(*) AS total_alerts
FROM
  `saml-d-aml-monitoring.aml_monitoring.rule_smurfing`;
