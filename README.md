# Bayesian Borrowing Workflow（初始化仓库）

本仓库用于整理一个当前写在 **Rmd / brms / RStan workflow** 中的 Bayesian borrowing analysis，并逐步将其拆解为：

- 可讨论的统计模型定义
- 可复用的输入 / 输出 / 配置契约
- 可迁移的 Stan / CmdStan 工作流
- 后续可对接工程实现、版本管理以及更安全执行环境的标准化流程

当前版本的重点是把现有原型分析中真正需要冻结的内容抽取出来，并建立清晰的边界。

---

## 仓库目标

这个仓库当前阶段主要服务于以下目标：

1. 将“Rmd里能跑通的示例原型分析”与“被清晰定义的统计模型”区分开
2. 用 contract 文档明确 workflow 的输入、输出、配置和预处理边界
3. 为后续 Stan model 转写、CmdStan 化、工程封装和协作分工提供稳定基础
4. 让统计人员、工程人员以及其他协作者可以围绕同一套文档进行对齐，而不是围绕零散脚本沟通

---

## 当前仓库内容

### 1. 原型分析

- `场景二-贝叶斯借用.Rmd`

这是当前 analysis prototype 的主要来源文件。  
它体现了当前在 R 环境下的分析流程、数据处理方式、Bayesian fitting 逻辑和结果输出方式。

需要注意的是：

- Rmd 是当前原型实现
- Rmd 不等于最终冻结的统计模型定义
- Rmd 中同时混杂了：
  - 数据处理
  - 预处理
  - 模型设定
  - 采样设置
  - 输出整理
  - 展示逻辑

因此，后续工作的核心之一，是把这些层次逐步拆开。

---

### 2. Step 0：四份 contract 文档

当前仓库已包含四份基础 contract 文档，用于定义 workflow 的外部边界。

#### `input_contract.md`
定义标准输入数据格式，包括：

- analysis-ready 输入表结构
- 字段名、类型、语义和编码
- 必填字段与条件必填字段
- 上游与下游边界

这份文档的作用是确保后续 Bayesian workflow 接收到的是固定格式、固定语义的数据输入。

---

#### `preprocessing_boundary.md`
定义哪些步骤属于上游预处理，哪些步骤属于 Bayesian inference execution。

当前版本明确：

- 原始数据读取
- 数据清洗
- covariate 重编码
- propensity score 估计
- IPTW 构造
- trimming
- source discount
- survival interval splitting（如适用）

都属于 Stan / CmdStan 之外的上游步骤。

而 Bayesian engine 只负责：

- 模型拟合
- posterior sampling
- raw output 生成
- summary 生成

---

#### `config_contract.md`
定义标准运行配置（runtime configuration），包括：

- 分析设置
- borrowing 相关参数
- trimming 规则
- survival cut points
- MCMC runtime settings

目标是把运行配置从脚本中剥离出来，避免硬编码。

---

#### `output_contract.md`
定义标准输出结构，包括：

- raw output
- summary output

其目标是确保 workflow 不仅能输出最终 summary，也能保留 posterior draws、diagnostics、metadata 和 run logs，为后续复核、重现和系统集成提供基础。

---

## 当前仓库的结构意义

这四份 contract 不替代统计模型本身。  
它们主要用于回答以下问题：

- 输入是什么？
- 输出是什么？
- 哪些步骤属于预处理？
- 哪些参数属于配置？
- 哪些边界在当前版本中必须冻结？

---

## 当前阶段不试图解决的问题
- 最终 Stan model 的完整手写实现
- CmdStan / C++ 的正式生产级封装
- GUI / API 层设计
- secure execution / encrypted computation 的正式接入
- plotting output 的完全标准化
- 全流程自动化部署

这些内容保留为后续阶段的扩展项。

目前这个仓库可以理解为一个用于冻结边界、整理模型、支持后续迁移与协作的初始化仓库

---

## 后续演进路径

### Step 0：冻结 workflow contracts
当前已形成初版：

- input contract
- preprocessing boundary
- config contract
- output contract

---

### 3. Step 0：冻结 workflow contracts
当前已形成初版，并补充如下内容：

- **input_contract.md**：明确数据格式、字段编码、单位规范
  - ✅ 补齐单位定义（time=months, age=years, albumin=g/L）
  - ✅ 已补齐：sex / ecog / stage 的编码规则
  - ✅ 已完成：biomarker 与 cont_y 定义为通用演示变量（新增5.4节）
    - biomarker：二分类演示（0=Negative, 1=Positive），支持后续映射至任何生物标志物
    - cont_y：连续演示（正态分布，均值55±6），支持映射至生化/影像/评分等指标

- **preprocessing_boundary.md**：明确哪些步骤属于上游、哪些属于Bayesian engine
  - ✅ 定义了所有预处理步骤的位置与责任方
  - ✅ 为后续工程化阶段明确了责任划分框架

- **config_contract.md**：标准运行配置
  - ✅ 完整补齐所有MCMC参数（chains=4, iter=2000, warmup=1000, seed=20260407）
  - ✅ 所有borrowing参数已明确（a0=0.5, trim参数, cut_points）

- **output_contract.md**：标准输出结构
  - ✅ 定义了raw output和summary output格式
  - ✅ metadata.json 的正式生成与保存（已在 Rmd L1258-1273 实现）

#### 🆕 附加产物
本阶段还生成了以下支持文档：

- **alignment_checklist.md**：原型↔契约对齐检查单
  - 逐一核对Rmd原型是否与四份contract对齐
  - 追踪完整度与待修复清单
  - 为Step 0的最终验收提供checklist

- **step1_model_spec_template.md**：Step 1统计模型规范模板（冻结版 v0.2）
  - 将 Step 1 的交付物格式与内容结构固定为当前原型的一致版本
  - 包含 estimand、模型框架、权重机制、prior 设置、诊断规则
  - 作为后续 Stan 转写前的唯一冻结参考

- **supplements/slides/slides.pdf**：Rmd / Stan workflow 可视化演示稿
  - 3页幻灯片，用于在评审和协作讨论中统一理解
  - 重点覆盖：Rmd可见性层、执行管道、工程与统计边界

---

### Step 0.5：对齐验证与冻结完成

已完成的工作：

#### ✅ 已完成 🔴
1. **完成 Input Contract 最后对齐** ✅
  - ✅ 将 biomarker 与 cont_y 定义为通用演示变量（不绑定具体临床指标）
  - ✅ 在 input_contract.md 新增 5.4 节「通用演示变量说明」
  - ✅ 在 alignment_checklist.md 更新状态：biomarker/cont_y 从 ⚠️ 改为 ✅
  - ✅ 在 Rmd 原型中补充变量应用说明与实际映射示例
  - 设计理念：演示阶段保持灵活性，为真实数据接入预留清晰接口和迁移规则

#### 已完成的补充项

#### 优先级 ✅ 
2. **在Rmd中补充编码校验逻辑**
  - 为 biomarker 和 cont_y 的取值范围补充输入检查
  - 在预处理阶段输出数据质量报告

#### 优先级 ✅ 
3. **配置完全外部化**
  - 修改Rmd，使其从 config.json 读取参数而非硬编码
  - 验证所有结果与原型一致

#### 优先级 ✅ 
4. **规范化输出结构**
  - ✅ 为每次运行生成唯一的 run_id（Rmd L1073-1076）
  - ✅ 创建 metadata.json 生成逻辑（Rmd L1258-1273）
  - ✅ 定义 warnings 收集机制（集成至诊断输出）

以上补充项已同步到 `contracts/alignment_checklist.md`，可进入 Step 1 冻结规范维护。

---

### Step 1：明确统计模型
基于已冻结的 Rmd 原型与 `docs/step1_model_spec_template.md`，明确统计模型规范如下：

- 模型目标
- 数据结构
- 参数定义
- likelihood
- prior
- borrowing mechanism
- estimand
- output summary 目标
- 诊断要求
- 与 config/config.json 的一致性


---

### Step 2：Stan 迁移（已完成对齐验证与结构整理）
在 Step 1 已冻结的前提下，将统计模型正式转写为 CmdStan workflow，包括：

**核心交付物（P0 - 必须）：**
- `step2_stan_migration/models/stan_model_binary.stan` - 二分类结局 Stan model
- `step2_stan_migration/models/stan_model_continuous.stan` - 连续结局 Stan model
- `step2_stan_migration/models/stan_model_survival.stan` - 生存结局 Stan model（分段指数）
- `step2_stan_migration/R/stan_data_preparation.R` - Rmd 输出→Stan data 转换
- `step2_stan_migration/R/stan_execution.R` - CmdStan 执行器（config.json 集成）
- `step2_stan_migration/R/stan_output_formatter.R` - Stan output→summary_output.json 转换
- `step2_stan_migration/step2_migration_checklist.md` - Stan↔Rmd 输出验证清单

**可选扩展（P1）：**
- metadata.json 完整生成（复用 Rmd 逻辑）
- Stan diagnostics 自动检查（同步 Rmd 阈值）

**当前进展（2026-04-29）：**
- ✅ CmdStan 环境安装完成（v2.38.0）
- ✅ `cmdstanr` 已可识别 CmdStan path 与 version
- ✅ 三个 Stan models（binary / continuous / survival）已完成
- ✅ Stan data preparation、execution、output formatter 与 alignment validation 脚本已归档到 `step2_stan_migration/R/`
- ✅ 对齐报告、最终报告和真实数据验证结果已归档到 `step2_stan_migration/reports/`
- ✅ 历史输出、日志和整理脚本已分别归档到 `archive/`、`artifacts/`、`tools/`
- ✅ Step 2 工作区已整理为稳定目录结构，可进入 Step 3 标准执行流程设计

---

### Step 2.5：Statistical Design Package / Spec-driven Generator

Step 2.5 面向统计设计人员。核心入口是 `spec/analysis_spec.R`，统计设计参数由该文件集中维护，然后自动生成 config、Stan input JSON、CmdStan validation outputs 和标准 summary / metadata / diagnostics 输出。

**新增稳定工作流：**
- `spec/analysis_spec.R`：统计设计人员主要修改入口
- `R/generate_config.R`：从 analysis spec 生成 `config/config.json`
- `R/generate_stan_data.R`：从 preprocessed data 生成 `data/stan_input_*.json`
- `R/select_stan_model.R`：按 outcome type 选择 `models/*.stan`
- `R/run_cmdstan_validation.R`：使用 cmdstanr 运行验证
- `R/format_outputs.R`：生成 `outputs/summary_output.json`、`metadata.json`、`diagnostics.json`
- `R/run_statistical_design_package.R`：一键 smoke test 总入口
- `models/`：Step 2.5 使用的稳定 Stan templates

**最小运行命令：**

```bash
Rscript R/run_statistical_design_package.R
```

当前阶段仍允许 R / cmdstanr，因为这是统计设计验证包，不是最终 R-free engine package。未来 R-free CmdStan Engine Package 会在 Step 3/4 中处理；本阶段重点是固定 analysis spec、config JSON、Stan input JSON、Stan template 和标准输出之间的接口。

更多说明见 `docs/statistical_design_package.md`。

---

### Step 3：形成标准执行流程
将以下部分解耦：

- preprocessing
- model file
- config
- execution
- output packaging

形成更稳定的 CmdStan / standard engine workflow。

---

### Step 4：支持进一步工程化或安全执行
在边界清晰后，再考虑：

- 工程封装
- CI / versioning
- secure execution
- encrypted / MPC 对接
- 平台化集成

---

## 当前使用建议

这个仓库当前正处于 **Step 0 完成 → Step 0.5 完成 → Step 1 冻结 → Step 2 对齐验证完成 → Step 2.5 设计包生成器完成 → Step 3 准备启动** 的阶段。建议按照以下顺序阅读和使用：

### 第一步：理解整体框架
1. 阅读本 README 的"仓库目标"和"当前仓库内容"部分，了解项目的整体目标
2. 浏览四份contract文档，理解输入/输出/配置/预处理的边界定义
3. 查看原型Rmd，对应理解当前分析的实际实现

### 第二步：完成Step 0最终对齐（100% ✅）

**已完成的完整清单：**
- ✅ **Input Contract** 冻结：数据格式、8个字段编码、单位规范、biomarker/cont_y 为通用演示变量
- ✅ **Preprocessing Boundary** 完成：预处理步骤与责任方清晰界定
- ✅ **Config Contract** 冻结：所有MCMC参数、borrowing参数、诊断阈值集中管理
- ✅ **Output Contract** 完成：元数据、诊断指标、输出文件格式规范

**Step 0.5 的三个已完成补充：**
1. ✅ **编码验证** (Rmd L64-130)：`validate_encoding()` 函数自动检测8个字段是否符合contract规范
2. ✅ **配置外部化** (Rmd L1132-1180)：所有参数从 `config/config.json` 读取，无硬编码依赖
3. ✅ **诊断自动检查** (Rmd L1392-1450)：`check_diagnostics()` 函数实时验证Rhat、ESS_bulk、divergent，可根据阈值决定是否中止

**Step 0.5 当前状态：**
- ✅ 已完成对齐验证、配置外部化和诊断自动检查
- ✅ 与 [docs/step1_model_spec_template.md](/Users/xinyuejia/Projects/POC_场景2/docs/step1_model_spec_template.md) 的冻结版 Step 1 规范保持一致
- ✅ 当前重点已转入 Step 1 的正式规范维护，而不是继续扩展 Step 0.5

**支撑文档：**
- ✅ `contracts/alignment_checklist.md`：四份contract对齐证明（100%）
- ✅ `config/config.json`：生产级配置文件（诊断阈值完整）
- ✅ `docs/step1_model_spec_template.md`：Step 1 冻结版统计模型规范已完成

### 第三步：推进Step 1（已冻结）
1. 基于 `docs/step1_model_spec_template.md` 的冻结版模板，维护统计模型规范
2. 从原型Rmd中提取并冻结：estimand、模型方程式、权重机制、prior 设置、诊断规则

### 第四步：查看 Step 2（Stan 迁移）
**Step 2 已完成目录整理、三模型实现、对齐验证与真实数据验证。** 推荐查看：
1. `step2_stan_migration/README.md`：Step 2 工作区说明与目录结构
2. `step2_stan_migration/models/`：三类 Stan 模型源文件
3. `step2_stan_migration/R/`：数据准备、执行、输出格式化和对齐验证脚本
4. `step2_stan_migration/reports/STEP2_FINAL_REPORT.md`：Stan 对齐验证最终报告
5. `step2_stan_migration/reports/STEP2_PROJECT_SUMMARY_WITH_REAL_DATA.md`：真实数据验证总结
6. `step2_stan_migration/step2_migration_checklist.md`：迁移验证清单与结论

### 第五步：运行 Step 2.5（Statistical Design Package）
1. 修改 `spec/analysis_spec.R` 中的参数级设置，例如 `a0`、trimming、cut points、MCMC 和 diagnostics thresholds
2. 运行 `Rscript R/run_statistical_design_package.R`
3. 查看自动生成的 `config/`、`data/` 和 `outputs/`
4. 只有 likelihood、borrowing mechanism、estimand 或协变量结构变化时，才需要修改 `models/*.stan`

### 第六步：后续阶段（Step 3+）
在 Step 2 Stan 迁移完成并验证后，再推进：
- Step 3：标准执行流程解耦（preprocessing / model / config / execution / packaging）
- Step 4：工程化封装与安全执行对接

---

## 适用对象与使用场景

### 本仓库当前主要面向

- **统计人员**：理解当前分析的模型结构，参与Step 1模型规范的编写
- **Bayesian workflow设计者**：评估当前的借用机制、权重策略、诊断规则是否合理
- **Stan / CmdStan实现者**：在Step 1完成后，基于冻结的统计模型进行Stan转写
- **工程协作者**：在Step 2后期，基于标准化的输入/输出contract进行系统集成
- **后续安全执行对接方**：基于清晰的预处理边界和配置契约，实现加密/MPC友好的工作流

### 典型使用场景

| 场景 | 操作 |
|---|---|
| 概览当前分析 | 阅读本 README、四份 contract 和 Rmd 原型 |
| 评审当前方法的合理性 | 查看 `docs/step1_model_spec_template.md` 的冻结版框架，对应原型逐项检查 |
| Stan 转写 / 复核 | 查看 `step2_stan_migration/models/`、`R/` 和 `reports/` 中已完成的 Stan 迁移产物 |
| 统计设计参数验证 | 修改 `spec/analysis_spec.R` 后运行 `Rscript R/run_statistical_design_package.R` |
| 后续工程化对接 | 基于 `contracts/alignment_checklist.md` 和 `step2_stan_migration/step2_migration_checklist.md` 确认 contract 与 Stan 输出一致 |

---

## 文件组织方式


```text
.
├── README.md
├── contracts/
│   ├── input_contract.md              （输入数据格式定义）
│   ├── preprocessing_boundary.md      （上游预处理边界定义）
│   ├── config_contract.md             （运行配置定义）
│   ├── output_contract.md             （输出结构定义）
│   └── alignment_checklist.md         （🆕 原型↔契约对齐检查单）
├── prototype/
│   └── 场景二-贝叶斯借用.Rmd         （当前原型实现）
├── docs/
│   └── step1_model_spec_template.md  （🆕 Step 1冻结版统计模型规范）
├── config/
│   └── config.json                    （生产级运行配置）
├── spec/
│   └── analysis_spec.R                （Step 2.5 统计设计入口）
├── R/
│   ├── generate_config.R
│   ├── generate_stan_data.R
│   ├── select_stan_model.R
│   ├── run_cmdstan_validation.R
│   ├── format_outputs.R
│   └── run_statistical_design_package.R
├── models/
│   ├── binary.stan
│   ├── continuous.stan
│   └── survival.stan
├── data/
│   ├── stan_input_binary.json
│   ├── stan_input_continuous.json
│   └── stan_input_survival.json
├── outputs/
│   ├── summary_output.json
│   ├── metadata.json
│   └── diagnostics.json
├── step2_stan_migration/
│   ├── README.md                      （Step 2 工作区说明）
│   ├── step2_migration_checklist.md   （Stan↔Rmd 迁移验证清单）
│   ├── R/
│   │   ├── stan_data_preparation.R
│   │   ├── stan_execution.R
│   │   ├── stan_output_formatter.R
│   │   └── stan_alignment_validation.R
│   ├── models/
│   │   ├── stan_model_binary.stan
│   │   ├── stan_model_continuous.stan
│   │   └── stan_model_survival.stan
│   ├── reports/                       （最终报告、对齐报告和 JSON 结果）
│   ├── artifacts/                     （运行日志与可重建产物）
│   ├── archive/                       （历史版本输出）
│   └── tools/                         （整理与辅助脚本）
└── supplements/
  └── slides/
    ├── slides.tex                （🆕 Beamer幻灯片源文件）
    └── slides.pdf                （🆕 编译后的流程演示幻灯片）
```

建议查看 `supplements/slides/slides.pdf` 作为当前 workflow 的展示入口。
