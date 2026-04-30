# Final Migration Validation 最终迁移验证

本文档是 final migration validation evidence 的主入口。

当前 migration chain 记录在以下文档中：

- Step 2.5 Statistical Design Package：`docs/statistical_design_package.md`
- Step 2.6 prototype-aligned validation detail：`docs/prototype_aligned_validation.md`
- Step 2.7 brms-vs-CmdStan comparison detail：`docs/brms_vs_cmdstan_comparison.md`
- Step 3 plaintext engine demo：`engine_package/README_for_encryption_team.md`

Machine-readable final validation evidence 的预期位置为：

```text
outputs/final_migration_validation_report.json
```

当前 supporting machine-readable evidence 包括：

```text
outputs/prototype_aligned_validation_report.json
outputs/prototype_reference_summary.json
outputs/prototype_cmdstan_comparison.json
```

Validation data 是 simulated / synthetic prototype-aligned data，不是真实临床数据，也不是真实 RWD。

Engine package 是 plaintext reference implementation。它不实现 encryption、MPC、TEE 或 secure-computation adaptation。
