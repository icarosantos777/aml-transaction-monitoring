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
