# Engine Package Manifest 文件清单

本文档仅作为文件清单。Workflow 说明见 `README.md`。

下列 reference inputs 和 expected outputs 来自 simulated / synthetic prototype-aligned data。该 package 是 plaintext reference implementation，不是 encryption、MPC 或 TEE implementation。

| 路径 | 类型 | 用途 | 状态 |
|---|---|---|---|
| `README.md` | documentation | plaintext engine demo 主 README | reference |
| `MANIFEST.md` | documentation | 文件清单 | reference |
| `config/config.json` | JSON config | 从 Step 2.5 镜像而来的 runtime config | reference |
| `models/binary.stan` | Stan model | binary outcome model | reference |
| `models/continuous.stan` | Stan model | continuous outcome model | reference |
| `models/survival.stan` | Stan model | survival outcome model | reference |
| `models/binary` | compiled executable | 本地编译生成的 binary model | generated |
| `models/continuous` | compiled executable | 本地编译生成的 continuous model | generated |
| `models/survival` | compiled executable | 本地编译生成的 survival model | generated |
| `data/stan_input_binary.json` | CmdStan JSON input | plaintext binary model input | reference |
| `data/stan_input_continuous.json` | CmdStan JSON input | plaintext continuous model input | reference |
| `data/stan_input_survival.json` | CmdStan JSON input | plaintext survival model input | reference |
| `scripts/compile_models.sh` | shell script | 使用 CmdStan 编译 Stan models | reference |
| `scripts/export_generated_cpp.sh` | shell script | export stanc-generated C++ model headers | reference |
| `scripts/run_binary.sh` | shell script | 运行 binary model | reference |
| `scripts/run_continuous.sh` | shell script | 运行 continuous model | reference |
| `scripts/run_survival.sh` | shell script | 运行 survival model | reference |
| `scripts/run_all.sh` | shell script | 运行全部 plaintext models | reference |
| `scripts/collect_outputs.py` | Python script | 汇总 lightweight plaintext summaries | reference |
| `generated_cpp/` | generated artifact directory | optional C++ inspection artifacts | generated |
| `generated_cpp/README.md` | documentation | explains generated C++ headers and inspection boundary | reference |
| `generated_cpp/binary.hpp` | stanc-generated C++ header | binary model-specific C++ inspection artifact; generated after running `scripts/export_generated_cpp.sh` | generated, optional |
| `generated_cpp/continuous.hpp` | stanc-generated C++ header | continuous model-specific C++ inspection artifact; generated after running `scripts/export_generated_cpp.sh` | generated, optional |
| `generated_cpp/survival.hpp` | stanc-generated C++ header | survival model-specific C++ inspection artifact; generated after running `scripts/export_generated_cpp.sh` | generated, optional |
| `expected_outputs/summary_output.json` | JSON output | contract-aligned reference summary | reference |
| `expected_outputs/metadata.json` | JSON output | reference metadata | reference |
| `expected_outputs/diagnostics.json` | JSON output | reference diagnostics | reference |
| `outputs/draws/` | runtime directory | CmdStan posterior CSV outputs | runtime output |
| `outputs/logs/` | runtime directory | CmdStan execution logs | runtime output |
| `outputs/summaries/` | runtime directory | plaintext collector summaries | runtime output |
| `outputs/summaries/plaintext_summary_output.json` | JSON output | lightweight plaintext demo summary | runtime output |
