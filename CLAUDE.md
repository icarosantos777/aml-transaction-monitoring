# CLAUDE.md

## Project purpose

This repository contains an educational AML transaction-monitoring MVP built with Python, BigQuery SQL and Looker Studio.

## Important constraints

- Do not use `is_laundering` or `transaction_pattern` inside detection rules.
- Labels may only be used in evaluation queries.
- Keep account identifiers as STRING.
- Never sum different currencies in the same group.
- Thresholds are exploratory, not regulatory.
- Prefer explainable SQL rules over opaque logic.
- Preserve the execution order of the six SQL files.
- Do not include credentials, service-account files or the original CSV.

## Expected final results

- Total transactions: 9,504,852
- Illicit transactions: 9,873
- Structuring alerts: 8,754
- Smurfing alerts: 13,701
- Combined alerts: 22,455
- Alerted transactions: 128,463
- True positives: 1,677
- Precision: 1.3054%
- Recall: 16.9857%
- F1-score: 2.4245%
- Alert rate: 1.3516%
- Precision lift: 12.57x

## AI-assisted development policy

Claude Code may assist with:

- refactoring;
- documentation;
- SQL review;
- naming consistency;
- test-query generation;
- repository organization.

Human validation is required for:

- AML interpretation;
- thresholds;
- query execution;
- result verification;
- business conclusions.
