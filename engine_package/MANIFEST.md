# Engine Package Manifest 文件清单

## 文档

- `README_for_encryption_team.md`：面向加密团队和工程评审人员的说明文档
- `MANIFEST.md`：plaintext engine demo package 的文件清单

## Runtime Config

- `config/config.json`：从 Step 2.5 镜像而来的 runtime config

## Statistical Model Template

- `models/binary.stan`：binary outcome Stan model template
- `models/continuous.stan`：continuous outcome Stan model template
- `models/survival.stan`：survival outcome Stan model template

## Input JSON

- `data/stan_input_binary.json`：binary model 使用的 CmdStan JSON input
- `data/stan_input_continuous.json`：continuous model 使用的 CmdStan JSON input
- `data/stan_input_survival.json`：survival model 使用的 CmdStan JSON input

## Execution Script

- `scripts/compile_models.sh`：使用 CmdStan 编译全部 Stan models
- `scripts/run_binary.sh`：运行 binary model 的 plaintext CmdStan execution
- `scripts/run_continuous.sh`：运行 continuous model 的 plaintext CmdStan execution
- `scripts/run_survival.sh`：运行 survival model 的 plaintext CmdStan execution
- `scripts/run_all.sh`：运行全部 plaintext CmdStan models
- `scripts/collect_outputs.py`：将 CmdStan CSV files 汇总为 lightweight plaintext summary

## Expected Output

- `expected_outputs/summary_output.json`：contract-aligned reference summary output
- `expected_outputs/metadata.json`：reference metadata output
- `expected_outputs/diagnostics.json`：reference diagnostics output

## Generated Output

- `outputs/draws/`：shell scripts 生成的 CmdStan posterior CSV files
- `outputs/logs/`：shell scripts 生成的 CmdStan execution logs
- `outputs/summaries/`：`collect_outputs.py` 生成的 plaintext demo summaries
- `outputs/summaries/plaintext_summary_output.json`：generated lightweight plaintext demo summary; partially aligned with output contract; diagnostics placeholders are null
