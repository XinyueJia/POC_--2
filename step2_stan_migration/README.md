# Step 2：Stan 迁移工作区

这个目录用于承接 Step 1 冻结后的 Stan / CmdStan 迁移工作。

## 推荐推进顺序

1. 先冻结输入输出接口：确认 Step 1 里的 estimand、权重、输出字段在 Stan 侧如何映射。
2. 实现 `stan_data_preparation.R`：把 Rmd / 预处理结果整理成 Stan data block 所需结构。
3. 实现三份 Stan model：binary、continuous、survival。
4. 实现 `stan_execution.R`：统一读取 `config/config.json` 并调用 CmdStan。
5. 实现 `stan_output_formatter.R`：把 Stan 输出整理成 `summary_output.json` 和必要的诊断信息。
6. 补齐 `step2_migration_checklist.md`：做 Rmd vs Stan 的输出对齐验证。

## 当前状态

- Step 2 已开始初始化。
- 当前优先级是先把目录骨架和验证清单落地，再逐个实现模型与执行层。
