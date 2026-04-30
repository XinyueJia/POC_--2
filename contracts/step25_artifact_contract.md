# Step 2.5 Artifact Contract: Statistical Design Package v0.1

## 1. 目的

本文档定义 Step 2.5 Statistical Design Package 的稳定 artifact schema，并冻结以下结构预期：

- `spec/analysis_spec.R`
- `config/config.json`
- `data/preprocessed_demo.rds`
- `data/stan_input_*.json`
- `outputs/summary_output.json`
- `outputs/metadata.json`
- `outputs/diagnostics.json`
- Step 3 `engine_package` mirrored inputs and expected outputs

本文档是对 Step 2.5 Statistical Design Package 的 global output contract 细化，不替代 `contracts/output_contract.md`。

目标是在保持 CmdStan engine package 和下游 engineering / secure-computation interface 稳定的前提下，支持统计设计人员未来进行 parameter-level extensions。

## 2. 范围

本文档覆盖：

- `spec/analysis_spec.R`
- `config/config.json`
- `data/preprocessed_demo.rds`
- `data/stan_input_binary.json`
- `data/stan_input_continuous.json`
- `data/stan_input_survival.json`
- `outputs/summary_output.json`
- `outputs/metadata.json`
- `outputs/diagnostics.json`
- `engine_package/data/*.json`
- `engine_package/expected_outputs/*.json`

本文档不覆盖：

- `brms` prototype internal object structure
- CmdStan internal C++ implementation
- secure computation / MPC / encryption runtime
- production deployment
- plot output

## 3. 版本

```yaml
contract_name: step25_artifact_contract
contract_version: "0.1"
model_name: borrowing_v1
status: frozen-for-current-demo
```

Version `0.1` 对应：

- `borrowing_v1`
- `binary`、`continuous` 和 `survival` outcomes
- multi-outcome `summary_output.json` wrapper
- 每个 outcome summary record 内部的 nested diagnostics object
- 通过 `engine_package` 完成 plaintext CmdStan engine handoff

## 4. analysis_spec.R Schema

`spec/analysis_spec.R` 必须定义具有以下稳定结构的 `analysis_spec`：

```r
analysis_spec <- list(
  model_name = "borrowing_v1",
  version = "0.1",
  outcome_types = c("binary", "continuous", "survival"),
  borrowing = list(
    method = "fixed_power_prior_weight",
    a0 = 0.5
  ),
  weighting = list(
    use_ps_weight = TRUE,
    trim_lower = 0.01,
    trim_upper = 0.99
  ),
  survival = list(
    cut_points = c(6, 12, 18, 24, 30)
  ),
  mcmc = list(
    chains = 4,
    iter = 2000,
    warmup = 1000,
    seed = 20260407
  ),
  diagnostics = list(
    rhat_threshold = 1.05,
    ess_bulk_min = 400,
    ess_tail_min = 400,
    divergent_allowed = 0,
    stop_on_failure = TRUE
  ),
  output = list(
    save_warmup = FALSE,
    output_dir = "outputs"
  ),
  paths = list(...)
)
```

在不改变 generated schemas 的前提下，统计设计工作可以进行 parameter-level changes。Structure-level changes 需要 bump contract version。这些参数不应在多个 R scripts 中重复 hard-code；`analysis_spec.R` 是 canonical statistical-design entry point。

## 5. config/config.json Schema

`config/config.json` 由 `spec/analysis_spec.R` 自动生成。手动修改 `config/config.json` 不应被视为主 workflow。

必需的 top-level sections 为：

- `metadata`：config version、creation metadata、description 和 status。
- `model`：model name 和 outcome type selection。
- `borrowing`：borrowing method 和 borrowing parameters。
- `weighting`：propensity-score weight usage 和 trimming parameters。
- `survival`：piecewise exponential model 的 survival cut points。
- `mcmc`：CmdStan runtime settings。
- `diagnostics`：用于验证 posterior sampling quality 的 thresholds。
- `output`：output behavior 和 output directory settings。
- `paths`：generation、synchronization 和 execution scripts 使用的 repo-relative paths。

`config/config.json` 是 Step 3 engine package runtime reference config。`paths` section 对下游 synchronization 和 execution scripts 具有重要作用。

## 6. Preprocessed Data Contract

`data/preprocessed_demo.rds` 是 R-side preprocessed artifact，不是 direct CmdStan input。Stan input JSON files 由该 RDS artifact 生成。

必需的 minimum fields：

- `trt`
- `bayes_w`
- `binary_y`
- `cont_y`
- `time`
- `status`

建议保留的 audit fields：

- `id`
- `source`
- `age`
- `sex`
- `ecog`
- `stage`
- `biomarker`
- `prior_tx`
- `albumin`
- `iptw`
- `iptw_trim`
- `source_discount`

当前 validation 使用 prototype-aligned simulated data。不得将该数据描述为真实临床数据。

## 7. Stan Input JSON Schema

Stan input JSON fields 必须与对应 `models/*.stan` 的 `data` block 精确匹配。这些 JSON files 是 direct CmdStan engine input boundary。未来新增 covariates 或改变任何 Stan data block 时，必须 bump contract version。

除非单独的 privacy and security design 明确允许，否则 JSON inputs 不应包含 raw clinical identifiers。

### 7.1 Binary Input

File: `data/stan_input_binary.json`

必需字段：

- `N`: integer, `N > 0`
- `y`: integer array length `N`, values `0` or `1`
- `trt`: integer array length `N`, values `0` or `1`
- `weights`: numeric array/vector length `N`, values `>= 0`

### 7.2 Continuous Input

File: `data/stan_input_continuous.json`

必需字段：

- `N`: integer, `N > 0`
- `y`: numeric array/vector length `N`
- `trt`: integer array length `N`, values `0` or `1`
- `weights`: numeric array/vector length `N`, values `>= 0`

### 7.3 Survival Input

File: `data/stan_input_survival.json`

必需字段：

- `N`: integer, `N > 0`
- `J`: integer, `J > 0`
- `event`: integer array length `N`, values `0` or `1`
- `interval`: integer array length `N`, values `1..J`
- `trt`: integer array length `N`, values `0` or `1`
- `exposure`: numeric array/vector length `N`, values `>= 0`
- `weights`: numeric array/vector length `N`, values `>= 0`

## 8. Summary Output Schema

`outputs/summary_output.json` 使用 Step 2.5 multi-outcome wrapper：

```json
{
  "run_id": "...",
  "model_name": "borrowing_v1",
  "analysis_spec_version": "0.1",
  "outcomes": [
    {
      "run_id": "...",
      "outcome_type": "binary",
      "estimand": "OR",
      "posterior_mean": 0.0,
      "posterior_median": 0.0,
      "ci_95_lower": 0.0,
      "ci_95_upper": 0.0,
      "benefit_probability": 0.0,
      "diagnostics": {
        "rhat_max": 1.0,
        "ess_bulk_min": 0,
        "ess_tail_min": 0,
        "n_divergent": 0,
        "diagnostics_passed": true
      },
      "warnings": []
    }
  ]
}
```

每个 `outcomes[]` element 对应 `contracts/output_contract.md` 中的一个 outcome-level summary record。Step 2.5 将 diagnostics 作为 nested object 保留在每个 outcome record 中。`warnings` 必须存在；无 warnings 时必须为 `[]`。

已冻结的 estimands：

- `binary`: `OR`
- `continuous`: `Mean difference`
- `survival`: `HR`

任何 field names、estimand definitions、credible interval definitions 或 diagnostics requirements 的变更，都需要 bump contract version。

## 9. Metadata Output Schema

`outputs/metadata.json` 记录一次 Step 2.5 run 的 artifact lineage。

必需字段：

- `run_id`
- `model_name`
- `analysis_spec_version`
- `generated_at`
- `config_path`
- `stan_input_paths`
- `model_paths`
- `cmdstan_run_paths`
- `output_paths`

Paths 应尽量使用 repo-relative paths。Metadata 必须支持未来 audit 和 `engine_package` handoff。

## 10. Diagnostics Output Schema

`outputs/diagnostics.json` 必须包含：

- `run_id`
- `diagnostics`
  - `binary`
  - `continuous`
  - `survival`
- `all_diagnostics_passed`

每个 outcome diagnostics object 必须包含：

- `rhat_max`
- `ess_bulk_min`
- `ess_tail_min`
- `n_divergent`
- `diagnostics_passed`

Diagnostics thresholds 来自 `analysis_spec$diagnostics`。缺失 diagnostics 的结果不应被视为完整可报告结果。若 `stop_on_failure = TRUE`，diagnostics failure 应阻止 validation 被标记为 completed。

## 11. Engine Package Synchronization Rule

Step 3 `engine_package` 通过以下 mappings 镜像 Step 2.5 / Step 2.6 / Step 2.7 artifacts：

- `config/config.json` -> `engine_package/config/config.json`
- `models/*.stan` -> `engine_package/models/*.stan`
- `data/stan_input_*.json` -> `engine_package/data/stan_input_*.json`
- `outputs/summary_output.json` -> `engine_package/expected_outputs/summary_output.json`
- `outputs/metadata.json` -> `engine_package/expected_outputs/metadata.json`
- `outputs/diagnostics.json` -> `engine_package/expected_outputs/diagnostics.json`

`engine_package/data/*.json` 是 CmdStan plaintext demo input。`engine_package/expected_outputs/*.json` 是 contract-aligned reference output。

`engine_package/scripts/collect_outputs.py` 可以生成与 reference summary fields 部分对齐的 lightweight output，但它不替代 `engine_package/expected_outputs/*.json`。

Engine package 是 plaintext reference implementation，不是 secure-computation implementation。

## 12. 允许的变更与破坏 contract 的变更

不需要 bump contract version 的 allowed parameter-level changes：

- `borrowing$a0`
- `weighting$trim_lower`
- `weighting$trim_upper`
- `survival$cut_points`
- `mcmc$chains`
- `mcmc$iter`
- `mcmc$warmup`
- `mcmc$seed`
- diagnostics thresholds
- output directory
- `outcome_types` subset selection，例如仅运行 `binary`

需要 bump version 的 contract-breaking changes：

- 增加或删除 required Stan input JSON field
- 修改 Stan data block
- 改变 estimand definition
- 改变 likelihood
- 在 engine-level Stan model 中加入 covariates
- 改变 borrowing mechanism
- 改变 `summary_output.json` field names
- 删除 diagnostics fields
- 改变 credible interval definition，例如从 95% 改为 90%
- 改变 `benefit_probability` definition
- 改变 metadata lineage fields
- 改变 `engine_package` expected output schema

## 13. 与其他 contracts 的关系

本文档位于 global workflow contracts 之下，并针对 Step 2.5 artifacts 进行专门细化：

- `contracts/output_contract.md`：global output contract。
- `contracts/config_contract.md`：general config-layer contract，如当前仓库存在。
- `contracts/input_contract.md`：raw input-layer contract，如当前仓库存在。
- `contracts/preprocessing_boundary.md`：preprocessing and Bayesian engine boundary，如当前仓库存在。
- `contracts/step25_artifact_contract.md`：Step 2.5 generated artifact contract。

如果其他 contract 与本文档存在重叠，应将本文档理解为 Step 2.5 artifact-level refinement，而不是对 global contract 的替代。

## 14. 验证状态

Contract v0.1 由当前 validation artifacts 支持：

- `outputs/prototype_aligned_validation_report.json`
- `outputs/prototype_cmdstan_comparison.json`
- `outputs/final_migration_validation_report.json`
- `docs/final_migration_validation.md`

当前 validation 使用 simulated data，不是真实临床数据。
