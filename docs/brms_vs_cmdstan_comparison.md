# Step 2.7：brms-vs-CmdStan numerical comparison

本文档是 supporting validation detail，不是 Step 2.5 主说明文档，也不是 engine package 主 README。主入口见 `docs/statistical_design_package.md` 和 `engine_package/README_for_encryption_team.md`。

## 目的

Step 2.6 已证明 Step 2.5 / CmdStan workflow 可以在 Rmd prototype 同源模拟数据上运行。Step 2.7 进一步在同一份 `data/preprocessed_demo.rds` 上运行 brms reference models，并将 brms reference summary 与 CmdStan summary 进行数值对照。

该步骤属于 migration validation，不引入新的 statistical model，不改变 estimand，不改变 borrowing mechanism，也不修改 Stan model。

## 与 Step 2.6 的区别

Step 2.6 验证 CmdStan workflow 是否能够在 prototype-aligned simulated data 上完成运行并生成 contract-aligned outputs。

Step 2.7 验证两个 Bayesian engines 在同源数据、同一模型结构和同一配置下是否给出方向一致、区间重叠、数量级接近且 diagnostics 合理的结果：

- brms / rstan reference models
- Step 2.5 hand-written Stan / cmdstanr models

由于 HMC sampling 存在随机性，brms 与 CmdStan 的输出不要求逐数字完全一致。当前比较重点是 direction consistency、credible interval overlap、posterior mean 数量级、benefit probability 和 diagnostics。

## 输入数据

比较使用的数据为：

```text
data/preprocessed_demo.rds
```

该文件由以下 Rmd prototype 同源模拟数据生成：

```text
prototype/demo_data_advanced.xlsx
```

该数据仍然是 synthetic / simulated data，不是真实研究数据。

## brms reference models

Binary outcome：

```r
binary_y | weights(bayes_w) ~ trt
family = bernoulli(link = "logit")
estimand = OR = exp(beta_trt)
```

Continuous outcome：

```r
cont_y | weights(bayes_w) ~ trt
family = gaussian()
estimand = Mean difference = beta_trt
```

Survival outcome：

```r
event | weights(bayes_w) ~ trt + interval + offset(log(exposure))
family = poisson()
estimand = HR = exp(beta_trt)
```

Survival 数据使用 `analysis_spec$survival$cut_points` 进行 interval splitting，并与 CmdStan input generator 保持一致。

## 运行方式

默认 quick mode：

```bash
Rscript R/run_brms_vs_cmdstan_comparison.R
```

Full mode：

```bash
Rscript R/run_brms_vs_cmdstan_comparison.R full
```

## quick mode 与 full mode

Quick mode 用于本地 migration sanity check：

- chains = 2
- iter = 1000
- warmup = 500

Full mode 使用 `spec/analysis_spec.R` 中的 MCMC settings：

- `analysis_spec$mcmc$chains`
- `analysis_spec$mcmc$iter`
- `analysis_spec$mcmc$warmup`
- `analysis_spec$mcmc$seed`

输出 JSON 会记录 `brms_mode`、`chains`、`iter`、`warmup` 和 `seed`，因此 quick mode 结果不会被误标记为 full validation。

## 当前 full mode 结果

当前已完成 full mode comparison：

```text
outputs/prototype_reference_summary.json
outputs/prototype_cmdstan_comparison.json
```

brms reference summary 使用：

- `brms_mode`: `full`
- `chains`: 4
- `iter`: 2000
- `warmup`: 1000
- `seed`: 20260407

总体比较结论：

- `comparison_status`: `completed`
- `mode`: `brms_vs_cmdstan`
- `all_directions_consistent`: `true`
- `all_intervals_overlap`: `true`
- `all_diagnostics_passed`: `true`

Outcome-level comparison：

| outcome_type | estimand | brms posterior_mean | CmdStan posterior_mean | absolute_difference | relative_difference | direction_consistent | intervals_overlap | both_diagnostics_passed |
|---|---:|---:|---:|---:|---:|---|---|---|
| binary | OR | 0.3694 | 0.3699 | 0.0005 | 0.0014 | true | true | true |
| continuous | Mean difference | -8.8279 | -8.7036 | 0.1243 | 0.0141 | true | true | true |
| survival | HR | 0.4324 | 0.4282 | 0.0042 | 0.0097 | true | true | true |

Benefit probability 在三类 outcome 中均为：

- brms: 1
- CmdStan: 1
- difference: 0

## 输出文件

brms reference summary：

```text
outputs/prototype_reference_summary.json
```

brms-vs-CmdStan comparison report：

```text
outputs/prototype_cmdstan_comparison.json
```

## 当前限制

- brms / rstan 运行速度慢于 CmdStan。
- brms 与 CmdStan 的结果不要求逐数字完全一致。
- quick mode 仅用于 migration sanity check；当前 full mode 结果才对应 `spec/analysis_spec.R` 中的 MCMC settings。
- 当前 comparison 使用 synthetic / simulated data，不代表真实研究数据验证。
