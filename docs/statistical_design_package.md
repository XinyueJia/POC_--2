# Statistical Design Package / Spec-driven Generator

## 目的

Step 2.5 面向统计设计人员。目标是把常规设计参数集中在 `spec/analysis_spec.R`，并由 R 脚本自动生成：

- `config/config.json`
- `data/stan_input_binary.json`
- `data/stan_input_continuous.json`
- `data/stan_input_survival.json`
- `outputs/summary_output.json`
- `outputs/metadata.json`
- `outputs/diagnostics.json`

当前阶段仍使用 R、cmdstanr、jsonlite、posterior 和 survival。它是统计设计验证包，不是最终 R-free engine。

## 统计设计人员主要修改哪里

主要入口是：

```text
spec/analysis_spec.R
```

通常可以修改的参数包括：

- `outcome_types`
- `borrowing$a0`
- `weighting$trim_lower`
- `weighting$trim_upper`
- `survival$cut_points`
- `mcmc$chains`
- `mcmc$iter`
- `mcmc$warmup`
- `mcmc$seed`
- `diagnostics$rhat_threshold`
- `diagnostics$ess_bulk_min`
- `diagnostics$ess_tail_min`
- `diagnostics$divergent_allowed`
- `diagnostics$stop_on_failure`

这些属于参数级变更。运行脚本会自动同步生成 config、Stan input、CmdStan validation outputs 和标准输出 JSON。

## 什么时候需要修改 Stan template

以下属于模型结构级变更，不能承诺由 `analysis_spec.R` 自动生成 Stan：

- likelihood 改变
- 加入协变量调整
- 加入 source-specific random effect
- 改 borrowing mechanism
- 改 estimand
- 改 treatment coefficient 的参数化方式
- 改生存模型结构，例如从 piecewise exponential 改为 Weibull 或 Cox-like 近似

这些变更需要同步修改：

```text
models/binary.stan
models/continuous.stan
models/survival.stan
R/generate_stan_data.R
R/format_outputs.R
```

## 自动生成的输出

运行：

```bash
Rscript R/run_statistical_design_package.R
```

会生成：

```text
config/config.json
data/stan_input_binary.json
data/stan_input_continuous.json
data/stan_input_survival.json
outputs/summary_output.json
outputs/metadata.json
outputs/diagnostics.json
outputs/cmdstan/<run_id>/<outcome_type>/
```

默认 demo data 是 synthetic preprocessed dataset，仅用于 workflow smoke test，不代表真实研究数据。

## 与未来 R-free package 的关系

Step 2.5 固定了未来 R-free CmdStan Engine Package 需要遵循的接口：

- analysis spec 的参数语义
- config JSON 结构
- Stan input JSON 字段名
- Stan template 的 data block
- summary、metadata、diagnostics 输出结构
- CmdStan run artifact 的目录约定

后续 Step 3/4 可以把当前 R generator 拆成 R-free engine package，保留同样的 JSON contract 和 Stan template 目录结构。R 在当前阶段用于统计设计验证；未来交付给加密专家或工程执行环境时，应替换为不依赖 R 的 config/data generation 和 CmdStan execution layer。
