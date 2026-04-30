# Step 2.5 Artifact Contract: Statistical Design Package v0.1

## 1. Purpose

This contract defines the stable artifact schema for the Step 2.5 Statistical Design Package. It freezes the expected structure of:

- `spec/analysis_spec.R`
- `config/config.json`
- `data/preprocessed_demo.rds`
- `data/stan_input_*.json`
- `outputs/summary_output.json`
- `outputs/metadata.json`
- `outputs/diagnostics.json`
- Step 3 `engine_package` mirrored inputs and expected outputs

This contract refines the global output contract for the Step 2.5 Statistical Design Package. It does not replace `contracts/output_contract.md`.

The goal is to support future parameter-level extensions by statistical designers while keeping the CmdStan engine package and downstream engineering / secure-computation interface stable.

## 2. Scope

This contract covers:

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

This contract does not cover:

- `brms` prototype internal object structure
- CmdStan internal C++ implementation
- secure computation / MPC / encryption runtime
- production deployment
- plot output

## 3. Version

```yaml
contract_name: step25_artifact_contract
contract_version: "0.1"
model_name: borrowing_v1
status: frozen-for-current-demo
```

Version `0.1` corresponds to:

- `borrowing_v1`
- `binary`, `continuous`, and `survival` outcomes
- the multi-outcome `summary_output.json` wrapper
- the nested diagnostics object inside each outcome summary record
- plaintext CmdStan engine handoff through `engine_package`

## 4. analysis_spec.R Schema

`spec/analysis_spec.R` must define `analysis_spec` with this stable structure:

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

Parameter-level changes are allowed for statistical design work when they do not change the generated schemas. Structure-level changes require a contract version bump. These parameters should not be repeatedly hard-coded across multiple R scripts; `analysis_spec.R` is the canonical statistical-design entry point.

## 5. config/config.json Schema

`config/config.json` is generated automatically from `spec/analysis_spec.R`. Manual edits to `config/config.json` should not be treated as the primary workflow.

The required top-level sections are:

- `metadata`: config version, creation metadata, description, and status.
- `model`: model name and outcome type selection.
- `borrowing`: borrowing method and borrowing parameters.
- `weighting`: propensity-score weight usage and trimming parameters.
- `survival`: survival cut points for the piecewise exponential model.
- `mcmc`: CmdStan runtime settings.
- `diagnostics`: thresholds used to validate posterior sampling quality.
- `output`: output behavior and output directory settings.
- `paths`: repo-relative paths used by generation, synchronization, and execution scripts.

`config/config.json` is the Step 3 engine package runtime reference config. The `paths` section is important for downstream synchronization and execution scripts.

## 6. Preprocessed Data Contract

`data/preprocessed_demo.rds` is an R-side preprocessed artifact. It is not a direct CmdStan input. Stan input JSON files are generated from this RDS artifact.

Required minimum fields:

- `trt`
- `bayes_w`
- `binary_y`
- `cont_y`
- `time`
- `status`

Recommended audit fields:

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

The current validation uses prototype-aligned simulated data. This data must not be described as real clinical data.

## 7. Stan Input JSON Schema

Stan input JSON fields must exactly match the corresponding `models/*.stan` data block. These JSON files are the direct CmdStan engine input boundary. Future additions of covariates or any change to a Stan data block require a contract version bump.

JSON inputs should not contain raw clinical identifiers unless a separate privacy and security design explicitly allows that.

### 7.1 Binary Input

File: `data/stan_input_binary.json`

Required fields:

- `N`: integer, `N > 0`
- `y`: integer array length `N`, values `0` or `1`
- `trt`: integer array length `N`, values `0` or `1`
- `weights`: numeric array/vector length `N`, values `>= 0`

### 7.2 Continuous Input

File: `data/stan_input_continuous.json`

Required fields:

- `N`: integer, `N > 0`
- `y`: numeric array/vector length `N`
- `trt`: integer array length `N`, values `0` or `1`
- `weights`: numeric array/vector length `N`, values `>= 0`

### 7.3 Survival Input

File: `data/stan_input_survival.json`

Required fields:

- `N`: integer, `N > 0`
- `J`: integer, `J > 0`
- `event`: integer array length `N`, values `0` or `1`
- `interval`: integer array length `N`, values `1..J`
- `trt`: integer array length `N`, values `0` or `1`
- `exposure`: numeric array/vector length `N`, values `>= 0`
- `weights`: numeric array/vector length `N`, values `>= 0`

## 8. Summary Output Schema

`outputs/summary_output.json` uses a Step 2.5 multi-outcome wrapper:

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

Each `outcomes[]` element corresponds to one outcome-level summary record in `contracts/output_contract.md`. Step 2.5 keeps diagnostics as a nested object inside each outcome record. `warnings` must exist and must be `[]` when no warnings are present.

Frozen estimands:

- `binary`: `OR`
- `continuous`: `Mean difference`
- `survival`: `HR`

Any change to field names, estimand definitions, credible interval definitions, or diagnostics requirements requires a contract version bump.

## 9. Metadata Output Schema

`outputs/metadata.json` records artifact lineage for one Step 2.5 run.

Required fields:

- `run_id`
- `model_name`
- `analysis_spec_version`
- `generated_at`
- `config_path`
- `stan_input_paths`
- `model_paths`
- `cmdstan_run_paths`
- `output_paths`

Paths should be repo-relative where practical. The metadata must support future audit and `engine_package` handoff.

## 10. Diagnostics Output Schema

`outputs/diagnostics.json` must contain:

- `run_id`
- `diagnostics`
  - `binary`
  - `continuous`
  - `survival`
- `all_diagnostics_passed`

Each outcome diagnostics object must contain:

- `rhat_max`
- `ess_bulk_min`
- `ess_tail_min`
- `n_divergent`
- `diagnostics_passed`

Diagnostics thresholds come from `analysis_spec$diagnostics`. Missing diagnostics should not be treated as a complete reportable result. If `stop_on_failure = TRUE`, diagnostics failure should prevent validation from being marked as completed.

## 11. Engine Package Synchronization Rule

Step 3 `engine_package` mirrors Step 2.5 / Step 2.6 / Step 2.7 artifacts through these mappings:

- `config/config.json` -> `engine_package/config/config.json`
- `models/*.stan` -> `engine_package/models/*.stan`
- `data/stan_input_*.json` -> `engine_package/data/stan_input_*.json`
- `outputs/summary_output.json` -> `engine_package/expected_outputs/summary_output.json`
- `outputs/metadata.json` -> `engine_package/expected_outputs/metadata.json`
- `outputs/diagnostics.json` -> `engine_package/expected_outputs/diagnostics.json`

`engine_package/data/*.json` is the CmdStan plaintext demo input. `engine_package/expected_outputs/*.json` is the contract-aligned reference output.

`engine_package/scripts/collect_outputs.py` may generate a lightweight output that partially aligns with the reference summary fields, but it does not replace `engine_package/expected_outputs/*.json`.

The engine package is a plaintext reference implementation. It is not a secure-computation implementation.

## 12. Allowed Changes vs Contract-Breaking Changes

Allowed parameter-level changes that do not require a contract version bump:

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
- `outcome_types` subset selection, for example running only `binary`

Contract-breaking changes requiring a version bump:

- adding or deleting a required Stan input JSON field
- modifying a Stan data block
- changing an estimand definition
- changing the likelihood
- adding covariates to an engine-level Stan model
- changing the borrowing mechanism
- changing `summary_output.json` field names
- deleting diagnostics fields
- changing the credible interval definition, for example from 95% to 90%
- changing the `benefit_probability` definition
- changing metadata lineage fields
- changing the `engine_package` expected output schema

## 13. Relationship to Other Contracts

This contract sits below the global workflow contracts and specializes them for Step 2.5 artifacts:

- `contracts/output_contract.md`: global output contract.
- `contracts/config_contract.md`, where available: general config-layer contract.
- `contracts/input_contract.md`, where available: raw input-layer contract.
- `contracts/preprocessing_boundary.md`, where available: preprocessing and Bayesian engine boundary.
- `contracts/step25_artifact_contract.md`: Step 2.5 generated artifact contract.

If another contract and this contract appear to overlap, this document should be read as the Step 2.5 artifact-level refinement, not as a replacement for the global contract.

## 14. Validation Status

Contract v0.1 is supported by the current validation artifacts:

- `outputs/prototype_aligned_validation_report.json`
- `outputs/prototype_cmdstan_comparison.json`
- `outputs/final_migration_validation_report.json`
- `docs/final_migration_validation.md`

The current validation uses simulated data, not real clinical data.
