# Step 2：Stan 迁移工作区

这个目录用于承接 Step 1 冻结后的 Stan / CmdStan 迁移工作。

## 环境状态（2026-04-28）

- CmdStan 已安装：`/Users/xinyuejia/.cmdstan/cmdstan-2.38.0`
- CmdStan 版本：`2.38.0`
- `cmdstanr` 已可正常加载并识别 CmdStan path
- `stan_model_binary.stan` 已完成编译与最小采样验证

## 最小环境配置（macOS）

1. 安装 R 依赖包：`cmdstanr`、`jsonlite`
2. 安装 CmdStan：`cmdstanr::install_cmdstan()`
3. 验证安装：
	- `cmdstanr::cmdstan_path()`
	- `cmdstanr::cmdstan_version()`

如遇 `processx.rdb is corrupt` 一类错误，重启 R 会话后重试；若仍失败，重装 `processx` / `callr` / `cmdstanr`。

## 最小采样验证（binary model）

可使用 `step2_stan_migration/stan_model_binary.stan` 进行验证：

1. 成功编译模型可执行文件
2. 使用小样本（1 chain、较短 warmup/sampling）完成一次采样
3. 能输出 `alpha`、`beta_trt`、`odds_ratio` 的 summary

## 推荐推进顺序

1. 先冻结输入输出接口：确认 Step 1 里的 estimand、权重、输出字段在 Stan 侧如何映射。
2. 实现 `stan_data_preparation.R`：把 Rmd / 预处理结果整理成 Stan data block 所需结构。
3. 实现三份 Stan model：binary、continuous、survival。
4. 实现 `stan_execution.R`：统一读取 `config/config.json` 并调用 CmdStan。
5. 实现 `stan_output_formatter.R`：把 Stan 输出整理成 `summary_output.json` 和必要的诊断信息。
6. 补齐 `step2_migration_checklist.md`：做 Rmd vs Stan 的输出对齐验证。

## 当前状态

- Step 2 已完成 CmdStan 环境安装与基础运行验证。
- 后续工作重点是推进执行输出对齐与 Stan↔Rmd 结果一致性验证。
