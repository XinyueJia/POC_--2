# Step 2：Stan 迁移工作区

这个目录用于承接 Step 1 冻结后的 Stan / CmdStan 迁移工作。

## 目录结构

- `models/`：Stan 模型源文件
  - `stan_model_binary.stan`：二分类结局模型
  - `stan_model_continuous.stan`：连续结局模型
  - `stan_model_survival.stan`：生存结局模型
- `R/`：Stan 侧数据准备、执行、输出格式化与对齐验证脚本
  - `stan_data_preparation.R`：将 analysis-ready / 原型输出整理为 Stan data block
  - `stan_execution.R`：统一 CmdStan 执行逻辑
  - `stan_output_formatter.R`：将 CmdStan 输出整理为 summary / diagnostics
  - `stan_alignment_validation.R`：Stan 与原型输出对齐验证
- `reports/`：最终报告、对齐报告、JSON 结果与真实数据验证结果
- `artifacts/`：运行日志与可重建产物
- `archive/`：历史版本输出
- `tools/`：整理与辅助脚本
- `stan_model_binary`、`stan_model_continuous`、`stan_model_survival`：本地编译生成的 CmdStan 可执行文件

## 环境状态（2026-04-29）

- CmdStan 已安装：`/Users/xinyuejia/.cmdstan/cmdstan-2.38.0`
- CmdStan 版本：`2.38.0`
- `cmdstanr` 已可正常加载并识别 CmdStan path
- 三个 Stan 模型均已完成实现与验证
- binary / continuous / survival 对齐验证均已通过
- 真实数据 binary 验证结果已归档到 `reports/step2_real_data_binary_alignment.json`

## 最小环境配置（macOS）

1. 安装 R 依赖包：`cmdstanr`、`jsonlite`
2. 安装 CmdStan：`cmdstanr::install_cmdstan()`
3. 验证安装：
	- `cmdstanr::cmdstan_path()`
	- `cmdstanr::cmdstan_version()`

如遇 `processx.rdb is corrupt` 一类错误，重启 R 会话后重试；若仍失败，重装 `processx` / `callr` / `cmdstanr`。

## 最小采样验证（binary model）

可使用 `step2_stan_migration/models/stan_model_binary.stan` 进行验证：

1. 成功编译模型可执行文件
2. 使用小样本（1 chain、较短 warmup/sampling）完成一次采样
3. 能输出 `alpha`、`beta_trt`、`odds_ratio` 的 summary

## 当前交付物

- `models/` 下三类 Stan model 已完成。
- `R/` 下保留通用执行链路脚本：数据准备、执行、输出格式化和对齐验证。
- `reports/STEP2_FINAL_REPORT.md` 汇总 Step 2 对齐验证结论。
- `reports/STEP2_PROJECT_SUMMARY_WITH_REAL_DATA.md` 汇总真实数据验证状态。
- `reports/step2_output_alignment_final.json`、`reports/step2_weighted_alignment_report.json` 与 `reports/step2_real_data_binary_alignment.json` 保留关键 JSON 结果。
- `archive/step2_output_alignment_v1.json` 保留早期输出基线。
- `artifacts/real_data_test.log` 保留真实数据验证日志。

## 当前状态

- Step 2 已从基础执行链路推进到完整对齐验证和真实数据验证。
- 目录已整理为 `R/`、`models/`、`reports/`、`artifacts/`、`archive/`、`tools/` 分层结构。
- 当前 README 只记录保留在仓库中的稳定脚本和产物；历史测试脚本已从根目录迁移/清理，不再作为推荐入口。
- 后续重点可转入 Step 3：将 preprocessing、model、config、execution、output packaging 进一步标准化为正式执行流程。
