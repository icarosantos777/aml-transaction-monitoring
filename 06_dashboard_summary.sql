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
--   dashboard_summary          (bruta, com linhas sobrepostas ALL_RULES/regras)
--   dashboard_summary_totals   (1 linha ALL_RULES, para scorecards)
--   dashboard_summary_by_rule  (linhas por regra, para gráficos/detalhamento)
--
-- DIFERENÇA ESSENCIAL:
--   total_alerts         = grupos agregados gerados pelas regras.
--   alerted_transactions = transações individuais dentro desses grupos.
--
-- POR QUE SEPARAR EM DUAS VIEWS:
--   dashboard_summary mistura, na mesma coluna rule_name, o total geral
--   (ALL_RULES) e as regras atômicas (STRUCTURING, SMURFING). Um scorecard
--   do Looker Studio que agregue essa view sem filtrar por rule_name (ex.:
--   SUM(total_alerts)) soma o total junto com as partes, duplicando o
--   resultado. Separando em duas views, os scorecards de total usam
--   dashboard_summary_totals (uma única linha, impossível somar errado) e
--   o controle "Filtrar por regra" nem alcança essa fonte.
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


-- dashboard_summary_totals: UMA linha (ALL_RULES), à prova de SUM.
-- Fonte dos scorecards de total no Looker Studio.
CREATE OR REPLACE VIEW
  `saml-d-aml-monitoring.aml_monitoring.dashboard_summary_totals`
AS
SELECT *
FROM `saml-d-aml-monitoring.aml_monitoring.dashboard_summary`
WHERE rule_name = 'ALL_RULES';


-- dashboard_summary_by_rule: só as regras atômicas.
-- Fonte dos gráficos por regra e do controle "Filtrar por regra".
CREATE OR REPLACE VIEW
  `saml-d-aml-monitoring.aml_monitoring.dashboard_summary_by_rule`
AS
SELECT *
FROM `saml-d-aml-monitoring.aml_monitoring.dashboard_summary`
WHERE rule_name IN ('STRUCTURING', 'SMURFING');


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
