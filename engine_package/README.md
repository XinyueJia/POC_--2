# Plaintext CmdStan Engine Demo Package 明文演示包

本文档是 Step 3 plaintext CmdStan engine demo 的唯一主 README。

## 目的

本 package 是面向 encryption experts、secure-computation experts 和 engineering reviewers 的 plaintext reference implementation。它展示 validated statistical design artifacts 如何交付给本地 CmdStan execution layer：

- Stan model files
- plaintext JSON inputs
- CmdStan compile / run scripts
- expected contract-aligned reference outputs
- runtime output folders

当前 demo inputs 来自 prototype-aligned simulated data。它们不是真实临床数据，也不是真实 RWD。

## 边界说明

本 package：

- 不实现 encryption
- 不实现 MPC
- 不实现 trusted execution environment
- 不拆解或修改 CmdStan internals
- 将 CmdStan 视为 plaintext external inference engine

Secure-computation adaptation 属于后续 engineering / cryptography task。Engineering teams 可以在保持 model / input / output contracts 不变的前提下，决定如何 package、sandbox、replace 或 adapt execution layer。

## 文件内容

```text
engine_package/
  README_for_encryption_team.md
  MANIFEST.md
  config/config.json
  models/binary.stan
  models/continuous.stan
  models/survival.stan
  data/stan_input_binary.json
  data/stan_input_continuous.json
  data/stan_input_survival.json
  scripts/compile_models.sh
  scripts/run_binary.sh
  scripts/run_continuous.sh
  scripts/run_survival.sh
  scripts/run_all.sh
  scripts/collect_outputs.py
  expected_outputs/summary_output.json
  expected_outputs/metadata.json
  expected_outputs/diagnostics.json
  outputs/draws/
  outputs/logs/
  outputs/summaries/
```

`MANIFEST.md` 仅作为文件清单。Workflow guide 以本文档为准。

## CmdStan 依赖

运行前需要在本地安装 CmdStan，并通过 `CMDSTAN` 环境变量暴露 installation root：

```bash
export CMDSTAN=/path/to/cmdstan
```

示例：

```bash
export CMDSTAN=$HOME/.cmdstan/cmdstan-2.38.0
```

## 运行 plaintext demo

在 repository root 运行：

```bash
export CMDSTAN=/path/to/cmdstan
bash engine_package/scripts/compile_models.sh
bash engine_package/scripts/run_all.sh
python engine_package/scripts/collect_outputs.py
```

如果本地 Python 命令为 `python3`，则使用 `python3` 替代 `python`。

Compile step 会构建：

```text
engine_package/models/binary
engine_package/models/continuous
engine_package/models/survival
```

`run_all.sh` 会运行全部三个 plaintext CmdStan models。也可以使用单模型脚本：

```bash
bash engine_package/scripts/run_binary.sh
bash engine_package/scripts/run_continuous.sh
bash engine_package/scripts/run_survival.sh
```

## 输入与输出

Plaintext CmdStan demo inputs 为：

```text
engine_package/data/*.json
```

这些文件是从 validated Step 2.5 / prototype-aligned workflow 镜像而来的 direct CmdStan JSON inputs。

Reference outputs 为：

```text
engine_package/expected_outputs/*.json
```

这些文件是 Step 2.5 validation workflow 生成的 contract-aligned reference outputs：

- `summary_output.json`
- `metadata.json`
- `diagnostics.json`

Local runtime outputs 为：

```text
engine_package/outputs/draws/
engine_package/outputs/logs/
engine_package/outputs/summaries/
```

`collect_outputs.py` 会写入 lightweight plaintext demo summary：

```text
engine_package/outputs/summaries/plaintext_summary_output.json
```

该 collector output 不是完整 production formatter。完整 reference diagnostics 应查看 `engine_package/expected_outputs/diagnostics.json`。

## 契约引用

详细 schema 保留在 contracts 中，不在本文档重复：

- `contracts/step25_artifact_contract.md`
- `contracts/output_contract.md`

`engine_package/data/*.json` 遵循 Step 2.5 artifact contract 中冻结的 Stan input schema。`engine_package/expected_outputs/*.json` 遵循 Step 2.5 artifact contract 和 global output contract。

## Demo data source

当前 engine package data 来自 Step 2.6 和 Step 2.7 validation 使用的 prototype-aligned simulated data。它仅用于 plaintext reference execution、migration validation 和 secure-computing handoff review。

它不是真实临床数据，也不是真实 RWD。

真实部署时，上游流程可以用相同 schema 的 JSON inputs 替换这些 demo inputs。该替换不应改变 Stan model interface、config contract 或 output contract。

## 最终迁移验证

最终迁移验证证据见：

```text
docs/final_migration_validation.md
outputs/final_migration_validation_report.json
```

Supporting validation details 见：

```text
docs/prototype_aligned_validation.md
docs/brms_vs_cmdstan_comparison.md
```

## 当前限制

- 本 package 不是 production secure-computation package。
- 本 package 不实现 encryption、MPC 或 TEE。
- 本 package 不包含 Docker、API servers、orchestration 或 deployment。
- Shell scripts 当前会镜像配置中的 MCMC settings，但不会从 JSON 动态解析所有 settings。
- `collect_outputs.py` 是 lightweight plaintext collector，不复现完整 R formatter。
- CmdStan 必须已在本地安装，并通过 `CMDSTAN` 指定。
