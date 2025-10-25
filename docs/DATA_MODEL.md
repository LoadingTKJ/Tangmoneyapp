# 数据模型概述

## SQLite 表
- `accounts`：账户元数据，包含币种、账单日、还款日等。
- `categories`：类别代码与名称。
- `transactions`：记录交易原币金额、汇率和基准币金额。
- `tags` / `transaction_tags`：标签与关联表。
- `recurring_rules`：周期账单配置，提醒提前天数。
- `rates_cache`：汇率缓存，按日期+币种存储。
- `sync_meta`：云盘同步版本与时间戳。
- `audit_log`：审计追踪，记录字段变更。

## 约束
- 交易金额以原币 + 汇率 + 基准币换算额存储，历史不自动重算。
- planned 交易在确认入账后与实际交易对冲。
