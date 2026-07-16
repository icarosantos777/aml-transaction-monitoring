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
