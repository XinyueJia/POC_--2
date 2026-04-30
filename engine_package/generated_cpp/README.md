# 生成的 C++ Headers

本目录存放可选的 `stanc` 生成 C++ model headers，用于 engineering / encryption inspection。

生成命令：

```bash
bash engine_package/scripts/export_generated_cpp.sh
```

预期生成文件：

- `binary.hpp`
- `continuous.hpp`
- `survival.hpp`

重要说明：

- 这些文件属于 generated artifacts。
- 不应手工修改这些文件。
- 统计 source of truth 仍然是 `engine_package/models/*.stan`。
- 如果 Stan model 发生变化，应重新运行 `export_generated_cpp.sh`。
- 这些 headers 暴露由 `stanc` 生成的 model-specific C++ classes。
- 本目录不随仓库内置 CmdStan runtime、HMC/NUTS services 或 Stan Math internals。
- Runtime internals 保留在 `$CMDSTAN` 指向的本地 CmdStan installation 中。

建议 encryption / engineering experts 按以下顺序进行检查：

1. `engine_package/README.md`
2. `engine_package/models/*.stan`
3. `engine_package/generated_cpp/*.hpp`
4. `$CMDSTAN/src/cmdstan/main.cpp`
5. `$CMDSTAN/src/cmdstan/command.hpp`
6. `$CMDSTAN/stan/src/stan/services/sample/`
7. `$CMDSTAN/stan/lib/stan_math/`
