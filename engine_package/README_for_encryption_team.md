# Plaintext CmdStan Engine Demo Package

## 目的

本 package 是面向加密专家、安全计算专家和工程评审人员的 plaintext reference implementation。它用于展示统计设计 workflow 产生的 model files、JSON input interface、CmdStan plaintext execution commands 以及 expected output structure。

边界说明：

- 本 package 不实现 encryption。
- 本 package 不实现 MPC。
- 本 package 不实现 trusted execution environment。
- 本 package 不拆解 CmdStan internals。
- CmdStan 在此处被视为外部 inference engine。
- 统计团队提供稳定的 model / input / output contracts 以及 plaintext reference outputs。
- 加密团队和工程团队负责决定如何封装、sandbox、替换或适配 execution layer。

## 1. Package Contents

```text
engine_package/
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

## 2. 本地依赖：CmdStan

运行本 package 前，需要在本地安装 CmdStan。脚本通过 `CMDSTAN` 环境变量定位 CmdStan installation root。

## 3. 设置 CMDSTAN

```bash
export CMDSTAN=/path/to/cmdstan
```

示例：

```bash
export CMDSTAN=$HOME/.cmdstan/cmdstan-2.38.0
```

## 4. 编译 Models

在仓库根目录运行：

```bash
bash engine_package/scripts/compile_models.sh
```

该命令会编译：

- `engine_package/models/binary`
- `engine_package/models/continuous`
- `engine_package/models/survival`

## 5. 运行单个 Model

```bash
bash engine_package/scripts/run_binary.sh
bash engine_package/scripts/run_continuous.sh
bash engine_package/scripts/run_survival.sh
```

shell scripts 当前镜像 `engine_package/config/config.json` 中的 MCMC runtime settings：

- warmup: `1000`
- sampling draws: `1000`
- seed: `20260407`

## 6. 运行全部 Models

```bash
bash engine_package/scripts/run_all.sh
```

## 7. 输出位置

posterior CSV files：

```text
engine_package/outputs/draws/
```

execution logs：

```text
engine_package/outputs/logs/
```

lightweight plaintext summary：

```bash
python engine_package/scripts/collect_outputs.py
# 或：python3 engine_package/scripts/collect_outputs.py
```

输出文件：

```text
engine_package/outputs/summaries/plaintext_summary_output.json
```

`collect_outputs.py` 仅使用 Python standard library。

## 8. Expected Outputs 的含义

`engine_package/expected_outputs/` 包含 Step 2.5 Statistical Design Package 生成的 reference outputs：

- `summary_output.json`：R / cmdstanr validation package 生成的标准统计 summary
- `metadata.json`：run metadata、paths、model name 以及 output contract references
- `diagnostics.json`：Rhat、ESS、divergent transition checks 以及 pass / fail status

这些文件用于展示一次成功 plaintext validation run 后应产生的 output schema。由于 HMC sampling 具有随机性且受环境影响，不同 CmdStan 执行之间的 posterior 数值不要求完全一致。

## 9. 统计设计人员可以修改的内容

统计设计人员通常在主仓库 workflow 中修改：

- `spec/analysis_spec.R`
- MCMC settings
- borrowing parameter `a0`
- trimming thresholds
- survival cut points
- diagnostic thresholds
- included outcome types

engine package 是已生成产物的 snapshot。当 statistical design contracts 发生变化时，应从 Step 2.5 重新生成并同步该 package。

## 10. 需要加密 / 工程团队负责的内容

加密团队和工程团队负责决定：

- CmdStan binaries 如何打包或替换
- JSON inputs 如何保护
- runtime artifacts 如何隔离
- logs 和 posterior draws 如何存储
- execution 如何 sandbox
- black-box CmdStan call 是否适合目标 secure-computation architecture
- 是否需要由其他 execution layer 复现相同的 model / input / output contract

## 11. 当前限制

- 本 package 不是 production secure-computation package。
- 本 package 不包含 Docker、API servers、orchestration 或 deployment。
- shell scripts 当前不会从 JSON 动态解析 MCMC runtime settings。
- 本 package 不完整复刻 R formatter；`collect_outputs.py` 只生成 lightweight plaintext demo summary。
- 本 package 假设本地已安装 CmdStan，并通过 `CMDSTAN` 环境变量指定位置。
