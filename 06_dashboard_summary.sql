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

  evaluation.true_positives + evaluation.false_negatives AS total_illicit_transactions,
  evaluation.total_transactions - evaluation.true_positives - evaluation.false_negatives AS total_normal_transactions,

  evaluation.alerted_transactions,

  evaluation.true_positives,
  evaluation.false_positives,
  evaluation.false_negatives,
  evaluation.true_negatives,

  evaluation.precision,
  evaluation.recall,
  evaluation.f1_score,
  evaluation.alert_rate,

  SAFE_DIVIDE(
    evaluation.true_positives + evaluation.false_negatives,
    evaluation.total_transactions
  ) AS dataset_laundering_rate,

  SAFE_DIVIDE(
    evaluation.precision,
    SAFE_DIVIDE(
      evaluation.true_positives + evaluation.false_negatives,
      evaluation.total_transactions
    )
  ) AS precision_lift

FROM
  `saml-d-aml-monitoring.aml_monitoring.rule_evaluation` AS evaluation

LEFT JOIN
  alert_counts
USING (rule_name);


CREATE OR REPLACE VIEW
  `saml-d-aml-monitoring.aml_monitoring.dashboard_summary_totals`
AS
SELECT
  total_alerts,
  total_transactions,
  total_illicit_transactions,
  total_normal_transactions,
  alerted_transactions,
  true_positives,
  false_positives,
  false_negatives,
  true_negatives,
  precision,
  recall,
  f1_score,
  alert_rate,
  dataset_laundering_rate,
  precision_lift
FROM `saml-d-aml-monitoring.aml_monitoring.dashboard_summary`
WHERE rule_name = 'ALL_RULES';


CREATE OR REPLACE VIEW
  `saml-d-aml-monitoring.aml_monitoring.dashboard_summary_by_rule`
AS
SELECT *
FROM `saml-d-aml-monitoring.aml_monitoring.dashboard_summary`
WHERE rule_name IN ('STRUCTURING', 'SMURFING');


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
  ROUND(dataset_laundering_rate * 100, 4) AS dataset_laundering_rate_pct,
  ROUND(precision_lift, 2) AS precision_lift
FROM
  `saml-d-aml-monitoring.aml_monitoring.dashboard_summary`
ORDER BY
  CASE rule_name
    WHEN 'STRUCTURING' THEN 1
    WHEN 'SMURFING' THEN 2
    WHEN 'ALL_RULES' THEN 3
  END;
