# Plaintext CmdStan Engine Package 明文演示包

Plaintext CmdStan engine demo 的主说明文档为：

```text
engine_package/README.md
```

本文档仅作为 `docs/` 目录下的 pointer 保留。

Engine package 是 plaintext reference implementation。当前 demo data 是 simulated / synthetic prototype-aligned data，不是真实临床数据，也不是真实 RWD。它不实现 encryption、MPC 或 TEE。

## Optional stanc-generated C++ inspection

Step 3 package primarily exposes a plaintext workflow:

```text
Stan model + JSON input + CmdStan execution + output contract
```

Step 3.1 can optionally export stanc-generated C++ headers. These headers help engineering / encryption experts inspect the model-specific C++ generated from each Stan model.

They do not replace the Stan files. The statistical source of truth remains `engine_package/models/*.stan`.

They do not include the full CmdStan runtime or Stan Math source code. For deeper runtime inspection, experts should inspect the local CmdStan installation.

Run from the repository root:

```bash
export CMDSTAN=/path/to/cmdstan
bash engine_package/scripts/export_generated_cpp.sh
```

Output contract 细节见：

```text
contracts/output_contract.md
contracts/step25_artifact_contract.md
```

Migration validation evidence 见：

```text
docs/final_migration_validation.md
```
