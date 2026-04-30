# Step 2.6：Prototype-aligned validation

本文档是 supporting validation detail，不是 Step 2.5 主说明文档，也不是 engine package 主 README。主入口见 `docs/statistical_design_package.md` 和 `engine_package/README_for_encryption_team.md`。

## 验证目的

Step 2.5 原本支持一份小型 synthetic smoke-test dataset，用于验证 spec-driven generator、Stan input JSON、CmdStan execution 和 output contract wiring。该 smoke-test 可用于 interface checks，但不足以证明迁移后的 Step 2.5 / CmdStan workflow 能在与原始 Rmd prototype scenario 对齐的数据上运行。

Step 2.6 尽可能使用与 Rmd prototype 相同的 simulated-data source：`prototype/demo_data_advanced.xlsx`。如果该文件不可用，export script 会回退到 Rmd prototype simulation logic。该步骤目标是 migration validation，不是新增 statistical model development。

## Rmd prototype data 与 Step 2.5 smoke-test data

Prototype-aligned data 表示原始 three-cohort simulated scenario：

- `Hainan_Treated`：current single-arm treated cohort
- `External_A`：external control source A
- `External_B`：external control source B
- binary、continuous 和 survival outcomes
- IPTW、source discount 和 Bayesian borrowing weights

Step 2.5 smoke-test data 规模更小，只用于证明 generator 和 CmdStan path 可以端到端运行。Step 2.6 使用 prototype-aligned simulated data 替换该 smoke-test input，同时复用 `spec/analysis_spec.R` 和 `config/config.json`。

## Input data source 数据来源

主要 input source 为：

```text
prototype/demo_data_advanced.xlsx
```

生成的 analysis-ready dataset 为：

```text
data/preprocessed_demo.rds
```

该数据仍是 synthetic / simulated data，不是真实研究数据。

## 生成的 Stan input JSON

运行 Step 2.6 会生成：

```text
data/stan_input_binary.json
data/stan_input_continuous.json
data/stan_input_survival.json
```

这些文件由 `data/preprocessed_demo.rds` 和共享的 `spec/analysis_spec.R` configuration 生成。

## 生成的 CmdStan outputs

如果本地 CmdStan 和 `cmdstanr` 可用，Step 2.6 会生成：

```text
outputs/summary_output.json
outputs/metadata.json
outputs/diagnostics.json
outputs/cmdstan/<run_id>/<outcome_type>/
```

Validation report 为：

```text
outputs/prototype_aligned_validation_report.json
```

Prototype-vs-CmdStan comparison report 为：

```text
outputs/prototype_cmdstan_comparison.json
```

## 运行方式

```bash
Rscript R/run_prototype_aligned_validation.R
```

该命令仅用于刷新 validation evidence。常规 handoff navigation 应从 `README.md` 开始。

## 当前限制

- 当前数据是 simulated data，不是真实研究数据。
- v0.1 不要求完整重跑 brms prototype。
- 如果 `outputs/prototype_reference_summary.json` 是 placeholder，Step 2.6 只表示 prototype-aligned CmdStan validation 已完成，不声称完成 full brms-vs-CmdStan numerical equivalence。
- 完整 numerical equivalence test 需要重新运行 Rmd/brms prototype，或导出真实 prototype reference summary，然后重新运行 `R/compare_prototype_and_cmdstan.R`。
- 完整 validation 需要本地 CmdStan / `cmdstanr` 环境。
