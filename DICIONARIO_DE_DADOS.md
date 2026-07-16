# Dicionário de Dados — AML Transaction Monitoring SAML-D

Este documento explica os campos usados no projeto, desde a tabela bruta até o dashboard.

Ele serve para:

- entender o significado de cada coluna;
- facilitar a reprodução do projeto;
- evitar confusão entre campos parecidos;
- ajudar outra pessoa ou IA a revisar as consultas;
- documentar a origem das métricas do dashboard.

> O dataset é sintético. As contas e transações não representam clientes reais.

---

# 1. Visão geral das tabelas

| Tabela ou view | Função |
|---|---|
| `raw_transactions` | Preserva os dados brutos como texto |
| `stg_transactions` | Converte os campos para os tipos corretos |
| `rule_structuring` | Gera alertas de Structuring |
| `rule_smurfing` | Gera alertas de Smurfing |
| `alerts` | Une os alertas das duas regras |
| `rule_evaluation` | Calcula o desempenho das regras |
| `dashboard_summary` | Prepara os indicadores do Looker Studio |

---

# 2. `raw_transactions`

Tabela bruta criada a partir do CSV original.

Todos os campos são mantidos como `STRING` para preservar os dados antes do tratamento.

| Campo | Tipo | Descrição |
|---|---|---|
| `date_raw` | STRING | Data original da transação |
| `time_raw` | STRING | Horário original da transação |
| `sender_account_raw` | STRING | Conta que enviou o valor |
| `receiver_account_raw` | STRING | Conta que recebeu o valor |
| `amount_raw` | STRING | Valor original da transação |
| `payment_currency_raw` | STRING | Moeda usada no pagamento |
| `received_currency_raw` | STRING | Moeda recebida pelo destinatário |
| `sender_bank_location_raw` | STRING | Localização do banco remetente |
| `receiver_bank_location_raw` | STRING | Localização do banco destinatário |
| `payment_type_raw` | STRING | Tipo de pagamento |
| `is_laundering_raw` | STRING | Label original: 1 para ilícita e 0 para normal |
| `laundering_type_raw` | STRING | Tipologia sintética da transação |

---

# 3. `stg_transactions`

View de staging usada para limpeza e conversão dos tipos.

| Campo | Tipo | Descrição |
|---|---|---|
| `transaction_date` | DATE | Data da transação |
| `transaction_time` | TIME | Horário da transação |
| `transaction_datetime` | DATETIME | Data e horário combinados |
| `sender_account` | STRING | Conta que enviou o valor |
| `receiver_account` | STRING | Conta que recebeu o valor |
| `amount` | NUMERIC | Valor da transação |
| `payment_currency` | STRING | Moeda usada no pagamento |
| `received_currency` | STRING | Moeda recebida pelo destinatário |
| `sender_bank_location` | STRING | Localização do banco remetente |
| `receiver_bank_location` | STRING | Localização do banco destinatário |
| `payment_type` | STRING | Tipo de pagamento |
| `is_laundering` | INT64 | Label do dataset: 1 para ilícita e 0 para normal |
| `transaction_pattern` | STRING | Tipologia sintética associada à transação |

## Observações

- `sender_account` e `receiver_account` permanecem como `STRING` porque são identificadores.
- `is_laundering` e `transaction_pattern` não são usados para criar alertas.
- As labels são usadas somente na avaliação.

---

# 4. `rule_structuring`

View que agrupa recebimentos por destinatário, semana e moeda.

Uma linha representa um alerta agregado.

| Campo | Tipo | Descrição |
|---|---|---|
| `alert_id` | STRING | Identificador único do alerta |
| `rule_name` | STRING | Nome da regra: `STRUCTURING` |
| `alerted_account` | STRING | Conta destinatária que gerou o alerta |
| `period_start` | DATE | Primeiro dia da semana analisada |
| `period_end` | DATE | Último dia da semana analisada |
| `payment_currency` | STRING | Moeda das transações do grupo |
| `transaction_count` | INT64 | Quantidade de transações no grupo |
| `distinct_senders` | INT64 | Quantidade de remetentes diferentes |
| `total_amount` | NUMERIC | Soma dos valores do grupo |
| `average_amount` | NUMERIC | Valor médio das transações |
| `min_individual_amount` | NUMERIC | Menor valor individual do grupo |
| `max_individual_amount` | NUMERIC | Maior valor individual do grupo |
| `first_transaction_datetime` | DATETIME | Data e horário da primeira transação |
| `last_transaction_datetime` | DATETIME | Data e horário da última transação |
| `alert_reason` | STRING | Explicação simples do motivo do alerta |

## Regra aplicada

```text
transaction_count >= 3
distinct_senders >= 3
total_amount >= 10000
max_individual_amount <= 10000
```

---

# 5. `rule_smurfing`

View que agrupa transações pelo mesmo remetente, destinatário, semana e moeda.

Uma linha representa um alerta agregado.

| Campo | Tipo | Descrição |
|---|---|---|
| `alert_id` | STRING | Identificador único do alerta |
| `rule_name` | STRING | Nome da regra: `SMURFING` |
| `alerted_account` | STRING | Conta destinatária principal do alerta |
| `related_account` | STRING | Conta remetente relacionada ao alerta |
| `period_start` | DATE | Primeiro dia da semana analisada |
| `period_end` | DATE | Último dia da semana analisada |
| `payment_currency` | STRING | Moeda das transações do grupo |
| `transaction_count` | INT64 | Quantidade de transações no grupo |
| `active_days` | INT64 | Número de dias diferentes com atividade |
| `activity_span_hours` | INT64 | Horas entre a primeira e a última transação |
| `total_amount` | NUMERIC | Soma dos valores do grupo |
| `average_amount` | NUMERIC | Valor médio das transações |
| `min_individual_amount` | NUMERIC | Menor valor individual do grupo |
| `max_individual_amount` | NUMERIC | Maior valor individual do grupo |
| `first_transaction_datetime` | DATETIME | Data e horário da primeira transação |
| `last_transaction_datetime` | DATETIME | Data e horário da última transação |
| `alert_reason` | STRING | Explicação simples do motivo do alerta |

## Regra aplicada

```text
transaction_count BETWEEN 3 AND 8
active_days >= 3
total_amount BETWEEN 6000 AND 25000
average_amount <= 4000
max_individual_amount <= 5000
activity_span_hours >= 48
```

---

# 6. `alerts`

View que une os alertas de Structuring e Smurfing.

| Campo | Tipo | Descrição |
|---|---|---|
| `alert_id` | STRING | Identificador único do alerta |
| `rule_name` | STRING | Regra que gerou o alerta |
| `alerted_account` | STRING | Conta principal que deve ser analisada |
| `related_account` | STRING | Conta relacionada, usada em Smurfing |
| `period_start` | DATE | Início da janela analisada |
| `period_end` | DATE | Final da janela analisada |
| `payment_currency` | STRING | Moeda do grupo |
| `transaction_count` | INT64 | Quantidade de transações do alerta |
| `distinct_senders` | INT64 | Remetentes distintos, usado em Structuring |
| `active_days` | INT64 | Dias ativos, usado em Smurfing |
| `activity_span_hours` | INT64 | Duração da atividade, usada em Smurfing |
| `total_amount` | NUMERIC | Valor total do alerta |
| `average_amount` | NUMERIC | Valor médio das transações |
| `min_individual_amount` | NUMERIC | Menor valor individual |
| `max_individual_amount` | NUMERIC | Maior valor individual |
| `first_transaction_datetime` | DATETIME | Primeira transação do grupo |
| `last_transaction_datetime` | DATETIME | Última transação do grupo |
| `alert_reason` | STRING | Motivo pelo qual o alerta foi criado |

## Campos que podem ficar nulos

| Campo | Quando fica nulo |
|---|---|
| `related_account` | Alertas de Structuring |
| `distinct_senders` | Alertas de Smurfing |
| `active_days` | Alertas de Structuring |
| `activity_span_hours` | Alertas de Structuring |

Isso ocorre porque as duas regras usam informações diferentes.

---

# 7. `rule_evaluation`

View usada para avaliar cada regra contra as labels do dataset.

Ela possui três linhas:

```text
STRUCTURING
SMURFING
ALL_RULES
```

| Campo | Tipo | Descrição |
|---|---|---|
| `rule_name` | STRING | Regra avaliada |
| `total_transactions` | INT64 | Total de transações da base |
| `alerted_transactions` | INT64 | Transações que pertencem a grupos alertados |
| `true_positives` | INT64 | Transações alertadas que eram ilícitas |
| `false_positives` | INT64 | Transações alertadas que eram normais |
| `false_negatives` | INT64 | Transações ilícitas que não foram alertadas |
| `true_negatives` | INT64 | Transações normais que não foram alertadas |
| `precision` | FLOAT64 | Percentual dos alertados que eram ilícitos |
| `recall` | FLOAT64 | Percentual dos ilícitos que foram encontrados |
| `f1_score` | FLOAT64 | Equilíbrio entre precision e recall |
| `alert_rate` | FLOAT64 | Percentual da base enviado para análise |

## Fórmulas

### Precision

```text
true_positives / (true_positives + false_positives)
```

### Recall

```text
true_positives / (true_positives + false_negatives)
```

### F1-score

```text
2 × true_positives
────────────────────────────────────────
2 × true_positives + false_positives + false_negatives
```

### Alert rate

```text
alerted_transactions / total_transactions
```

---

# 8. `dashboard_summary`

View resumida usada nos cards do Looker Studio.

Ela possui três linhas:

```text
STRUCTURING
SMURFING
ALL_RULES
```

| Campo | Tipo | Descrição |
|---|---|---|
| `rule_name` | STRING | Regra ou resultado combinado |
| `total_alerts` | INT64 | Quantidade de alertas agregados |
| `total_transactions` | INT64 | Total de transações da base |
| `total_illicit_transactions` | INT64 | Total de transações ilícitas |
| `total_normal_transactions` | INT64 | Total de transações normais |
| `alerted_transactions` | INT64 | Total de transações dentro dos alertas |
| `true_positives` | INT64 | Alertadas e ilícitas |
| `false_positives` | INT64 | Alertadas e normais |
| `false_negatives` | INT64 | Não alertadas e ilícitas |
| `true_negatives` | INT64 | Não alertadas e normais |
| `precision` | FLOAT64 | Taxa de acerto da fila de alertas |
| `recall` | FLOAT64 | Percentual dos ilícitos encontrados |
| `f1_score` | FLOAT64 | Equilíbrio entre precision e recall |
| `alert_rate` | FLOAT64 | Percentual da base enviado para análise |
| `dataset_laundering_rate` | FLOAT64 | Prevalência de lavagem na base completa |
| `precision_lift` | FLOAT64 | Quantas vezes a fila concentra mais lavagem que a base |

## Diferença importante

```text
total_alerts
```

é a quantidade de grupos gerados pelas regras.

```text
alerted_transactions
```

é a quantidade de transações individuais dentro desses grupos.

Esses campos não representam a mesma coisa.

---

# 9. Campos usados no Looker Studio

## Cards consolidados

Fonte:

```text
dashboard_summary
```

Filtro:

```text
rule_name = ALL_RULES
```

Agregação:

```text
MAX
```

| Card | Campo |
|---|---|
| Total de transações | `total_transactions` |
| Transações ilícitas | `total_illicit_transactions` |
| Alertas | `total_alerts` |
| Transações alertadas | `alerted_transactions` |
| Alert rate | `alert_rate` |
| Precision lift | `precision_lift` |
| Precision | `precision` |
| Recall | `recall` |
| F1-score | `f1_score` |

## Gráficos e tabela operacional

Fonte:

```text
alerts
```

Campos principais:

```text
rule_name
alerted_account
related_account
period_start
period_end
payment_currency
transaction_count
total_amount
average_amount
max_individual_amount
alert_reason
```

---

# 10. Resumo dos campos mais importantes

| Campo | Explicação simples |
|---|---|
| `sender_account` | Quem enviou |
| `receiver_account` | Quem recebeu |
| `amount` | Quanto foi transferido |
| `payment_currency` | Moeda usada |
| `is_laundering` | Resposta correta do dataset |
| `transaction_pattern` | Tipologia sintética |
| `alert_id` | Código do alerta |
| `alerted_account` | Conta principal a ser investigada |
| `transaction_count` | Quantas transações existem no grupo |
| `total_amount` | Soma dos valores |
| `distinct_senders` | Quantos remetentes diferentes enviaram |
| `active_days` | Em quantos dias houve atividade |
| `precision` | Quantos alertas estavam corretos |
| `recall` | Quantos casos ilícitos foram encontrados |
| `alert_rate` | Quanto da base foi enviado para análise |
| `precision_lift` | Quanto a fila é melhor que selecionar ao acaso |

---

# 11. Observações finais

- As labels são usadas somente na avaliação.
- As contas permanecem como texto.
- As moedas são analisadas separadamente.
- Os limites das regras são exploratórios.
- Um alerta não confirma lavagem.
- O alerta apenas prioriza uma investigação humana.
