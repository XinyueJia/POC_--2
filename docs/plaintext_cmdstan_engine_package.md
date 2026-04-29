# Plaintext CmdStan Engine Demo Package

## 本阶段的目的

Step 2.5 已经为统计设计人员创建了 Statistical Design Package。该 package 使用 R 和 cmdstanr 生成 config JSON、Stan input JSON、validation outputs 以及标准 summary。

Step 3 将这些已生成的产物打包为一个 plaintext CmdStan engine demo，供加密专家和工程专家评审。该阶段的核心目的，是在开展任何 secure-computation 工作之前，明确模型、输入、输出和执行层之间的边界。

## 责任边界

统计团队负责：

- Stan model templates
- input JSON field contracts
- runtime config semantics
- expected output schema
- plaintext reference outputs
- OR、mean difference、HR、diagnostics 和 benefit probability 的统计解释

加密团队和工程团队负责：

- CmdStan binaries 的处理方式
- input JSON 的保护方式
- output artifacts 的隔离或加密方式
- runtime execution 的 sandbox 方案
- 是否封装、替换或适配 CmdStan
- 生产部署和运行控制

## 将 CmdStan 视为 Black-box Engine 的原因

在 Step 3 中，CmdStan 被视为外部 inference engine。engine package 展示以下最小执行边界：

1. 编译 Stan model；
2. 将 JSON data 传递给已编译模型；
3. 以 plaintext 方式运行 HMC sampling；
4. 收集 posterior CSV output；
5. 将 `beta_trt` 转换为预期的 estimand summary。

该阶段不要求理解或修改 CmdStan internals。

## 稳定 Contract

该 package 对外暴露的稳定 contract 包括：

- `engine_package/models/*.stan`
- `engine_package/data/*.json`
- `engine_package/config/config.json`
- `engine_package/expected_outputs/*.json`

这些文件定义了后续执行层需要保持一致的 model / input / output boundary。

## Step 3 明确不包含的内容

- MPC
- encryption implementation
- trusted execution environment
- Docker 或生产部署
- API server
- Shiny application
- 重写 CmdStan C++
- 修改 HMC internals
- posterior draws 的安全存储
- production-grade audit logging

## 运行 Plaintext Demo

```bash
export CMDSTAN=/path/to/cmdstan
bash engine_package/scripts/compile_models.sh
bash engine_package/scripts/run_all.sh
python engine_package/scripts/collect_outputs.py
# 或：python3 engine_package/scripts/collect_outputs.py
```

生成的 plaintext outputs 位于：

```text
engine_package/outputs/
```
