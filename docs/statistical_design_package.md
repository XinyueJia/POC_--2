# Statistical Design Package / Spec-driven Generator 统计设计包

本文档是 Step 2.5 的唯一主说明文档。

## 目的

Step 2.5 为统计设计人员提供一个稳定入口，用于维护 design-level parameters，并生成 CmdStan validation workflow 和 plaintext engine handoff 所需的 artifacts。

主要可编辑入口为：

```text
spec/analysis_spec.R
```

当前 package 使用 simulated / synthetic prototype-aligned data 进行 validation。该数据不是真实临床数据，也不是真实 RWD。

## 统计设计人员可以修改的内容

Parameter-level changes 通常应在 `spec/analysis_spec.R` 中完成，包括：

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

以上内容属于 parameter-level settings，不应静默改变 Stan input JSON schema 或 expected output schema。

Model-structure changes 需要同步更新更广范围的内容。例如 likelihood 变更、加入 covariates、变更 borrowing mechanism、变更 estimand，或替换 survival model structure。此类变更需要同步更新 Stan models、generator / formatter code 和相关 contracts。

## 运行命令

在 repository root 运行：

```bash
Rscript R/run_statistical_design_package.R
```

## 自动生成的 artifacts

Step 2.5 generator 会生成主要 config、Stan input JSON 和 reference output artifacts：

```text
config/config.json
data/stan_input_binary.json
data/stan_input_continuous.json
data/stan_input_survival.json
outputs/summary_output.json
outputs/metadata.json
outputs/diagnostics.json
```

CmdStan runtime artifacts 也可能写入：

```text
outputs/cmdstan/<run_id>/<outcome_type>/
```

## 与 contract 的关系

本文档不重复完整 schema。

- `contracts/step25_artifact_contract.md` 冻结 Step 2.5 artifact schema。
- `contracts/output_contract.md` 定义 global output structure。

`contracts/step25_artifact_contract.md` 是对 global output contract 在本 package 中的细化。若变更影响 generated schemas、estimands、Stan `data` blocks、model likelihoods 或 borrowing mechanism，应更新 Step 2.5 artifact contract，并同步 engine package snapshot。

## 与 engine package 的关系

Step 2.5 生成 Step 3 plaintext engine package 消费或镜像的 artifacts：

- runtime config
- Stan input JSON
- expected summary / metadata / diagnostics outputs
- Stan model interface assumptions

Step 3 engine package 是这些 artifacts 的 plaintext handoff snapshot。其主 README 为：

```text
engine_package/README_for_encryption_team.md
```

Engine package 不是 secure-computation implementation。它不实现 encryption、MPC、TEE，也不修改 CmdStan internals。
