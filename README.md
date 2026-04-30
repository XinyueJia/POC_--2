# Bayesian Borrowing CmdStan 迁移包

本仓库用于记录并验证 Bayesian borrowing 原型从 Rmd / brms / RStan workflow 迁移到 contract 驱动的 Stan / CmdStan 交付包的过程。

当前仓库状态覆盖：

- Step 1：statistical model specification
- Step 2：Stan migration
- Step 2.5：Statistical Design Package / spec-driven generator
- Step 2.6：prototype-aligned validation
- Step 2.7：brms-vs-CmdStan comparison
- Step 3：plaintext CmdStan engine demo package
- Step 2.5 artifact contract

当前 validation 和 engine demo 使用的是 simulated / synthetic prototype-aligned data。该数据不是真实临床数据，也不是真实 RWD。

当前 engine package 是 plaintext reference implementation。它不实现 encryption、MPC、trusted execution，也不实现 secure-computation runtime adaptation。相关内容属于后续工程和加密任务。

## 验证状态

当前仓库已经具备针对当前 demo model 的完整 statistical-to-CmdStan-to-engine-demo 迁移链路：

- Step 2.5 从 `spec/analysis_spec.R` 生成 config、Stan input JSON 和 contract-aligned output artifacts。
- Step 2.6 在 prototype-aligned simulated data 上验证 CmdStan workflow。
- Step 2.7 在同源 simulated data 上记录 brms-vs-CmdStan numerical comparison 细节。
- Step 3 提供面向 encryption 和 engineering review 的 plaintext CmdStan handoff snapshot。

最终验证证据的入口为 `docs/final_migration_validation.md`；若当前 checkout 中存在 machine-readable evidence，则对应文件为 `outputs/final_migration_validation_report.json`。Supporting validation detail 保留在 `docs/prototype_aligned_validation.md` 和 `docs/brms_vs_cmdstan_comparison.md`。

## 最短运行路径

运行 Statistical Design Package：

```bash
Rscript R/run_statistical_design_package.R
```

仅在需要刷新 validation evidence 时运行 supporting validation scripts：

```bash
Rscript R/run_prototype_aligned_validation.R
Rscript R/run_brms_vs_cmdstan_comparison.R
# 如果当前 checkout 中存在 final report generator：
Rscript R/generate_final_migration_validation_report.R
```

运行 plaintext engine demo：

```bash
export CMDSTAN=/path/to/cmdstan
bash engine_package/scripts/compile_models.sh
bash engine_package/scripts/run_all.sh
python engine_package/scripts/collect_outputs.py
```

如果本地 Python 命令为 `python3`，则使用 `python3` 替代 `python`。

## 应阅读哪个文档

| 角色 / 目的 | 推荐阅读 |
|---|---|
| 统计设计人员 | `docs/statistical_design_package.md` |
| Step 2.5 artifact schema 维护者 | `contracts/step25_artifact_contract.md` |
| 全局输出格式审阅者 | `contracts/output_contract.md` |
| Encryption / engineering expert | `engine_package/README.md` |
| 最终迁移验证审阅者 | `docs/final_migration_validation.md` |
| brms-vs-CmdStan validation detail 审阅者 | `docs/brms_vs_cmdstan_comparison.md` |
| Prototype-aligned validation detail 审阅者 | `docs/prototype_aligned_validation.md` |

## 主文档索引

### 主说明文档

- `docs/statistical_design_package.md` 是 Step 2.5 的唯一主说明文档。
- `engine_package/README.md` 是 plaintext CmdStan engine demo 的唯一主 README。

### 契约文档

- `contracts/output_contract.md` 定义 global output contract。
- `contracts/step25_artifact_contract.md` 定义 Step 2.5 generated artifact contract，并对 global output contract 进行 Step 2.5 级别的细化。
- `contracts/input_contract.md`、`contracts/config_contract.md` 和 `contracts/preprocessing_boundary.md` 记录更广义的 workflow boundary。

Schema 细节保留在 contract 文档中，不在 README 中重复维护。

### 验证证据

- `docs/final_migration_validation.md` 是 final migration validation evidence 的主入口。
- `outputs/final_migration_validation_report.json` 是预期的 machine-readable final validation report。
- `docs/prototype_aligned_validation.md` 是 Step 2.6 的 supporting validation detail。
- `docs/brms_vs_cmdstan_comparison.md` 是 Step 2.7 的 supporting validation detail。
- `outputs/prototype_aligned_validation_report.json`、`outputs/prototype_reference_summary.json` 和 `outputs/prototype_cmdstan_comparison.json` 是 supporting machine-readable validation artifacts。

## Step 2.5：Statistical Design Package

主说明文档：`docs/statistical_design_package.md`

统计设计主入口：

```text
spec/analysis_spec.R
```

最小运行命令：

```bash
Rscript R/run_statistical_design_package.R
```

Generator 生成：

- `config/config.json`
- `data/stan_input_binary.json`
- `data/stan_input_continuous.json`
- `data/stan_input_survival.json`
- `outputs/summary_output.json`
- `outputs/metadata.json`
- `outputs/diagnostics.json`

详细 schema 冻结在 `contracts/step25_artifact_contract.md`；global output rules 见 `contracts/output_contract.md`。

## Step 3：Plaintext CmdStan Engine Demo

主 README：`engine_package/README.md`

Engine package 是 plaintext handoff snapshot，包含：

- 从 Step 2.5 / validation 镜像而来的 config 和 Stan input JSON
- Stan model files
- 用于本地 CmdStan execution 的 shell scripts
- contract-aligned reference outputs
- local runtime output folders

该 package 将 CmdStan 视为外部 plaintext inference engine。它不实现 encryption、MPC、TEE，也不修改 CmdStan internals。

### Optional C++ inspection

如果 encryption / engineering experts 需要查看 stanc-generated model-specific C++ headers，可以运行：

```bash
export CMDSTAN=/path/to/cmdstan
bash engine_package/scripts/export_generated_cpp.sh
```

输出位于：

```text
engine_package/generated_cpp/
```

这一步只导出 C++ inspection artifacts，不运行 MCMC，不改变统计结果，不实现 encryption。`engine_package/models/*.stan` 仍然是 statistical source of truth。

## 仓库结构

```text
.
├── README.md
├── spec/
│   └── analysis_spec.R
├── R/
│   ├── run_statistical_design_package.R
│   ├── run_prototype_aligned_validation.R
│   └── run_brms_vs_cmdstan_comparison.R
├── contracts/
│   ├── output_contract.md
│   └── step25_artifact_contract.md
├── docs/
│   ├── statistical_design_package.md
│   ├── final_migration_validation.md
│   ├── prototype_aligned_validation.md
│   ├── brms_vs_cmdstan_comparison.md
│   └── plaintext_cmdstan_engine_package.md
├── data/
│   └── stan_input_*.json
├── outputs/
│   ├── summary_output.json
│   ├── metadata.json
│   ├── diagnostics.json
│   └── *_validation*.json
├── models/
│   ├── binary.stan
│   ├── continuous.stan
│   └── survival.stan
└── engine_package/
    ├── README.md
    ├── MANIFEST.md
    ├── config/
    ├── data/
    ├── models/
    ├── scripts/
    ├── expected_outputs/
    └── outputs/
```

## 范围边界

本仓库不声称 secure computation 已完成。当前 secure-computation adaptation 仍属于后续 engineering 和 cryptography 工作。

不得将当前 demo inputs 描述为真实临床数据。它们是用于 migration validation 和 plaintext engine handoff 的 simulated / synthetic prototype-aligned data。
