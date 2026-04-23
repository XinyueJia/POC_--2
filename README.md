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

这些内容属于后续阶段。

目前这个仓库可以理解为一个用于冻结边界、整理模型、支持后续迁移与协作的初始化仓库

---

## 后续演进路径

### Step 0：冻结 workflow contracts
当前已完成初版：

- input contract
- preprocessing boundary
- config contract
- output contract

---

### 3. Step 0：冻结 workflow contracts
当前已完成初版，并补充了以下内容：

- **input_contract.md**：明确数据格式、字段编码、单位规范
  - ✅ 补齐单位定义（time=months, age=years, albumin=g/L）
  - ⚠️ 待补充：分类变量具体编码规则（sex, ecog, stage, biomarker）
  - ⚠️ 待明确：cont_y的实际含义与单位

- **preprocessing_boundary.md**：明确哪些步骤属于上游、哪些属于Bayesian engine
  - ✅ 定义了所有预处理步骤的位置与责任方
  - ✅ 为后续工程化阶段明确了责任划分框架

- **config_contract.md**：标准运行配置
  - ✅ 完整补齐所有MCMC参数（chains=4, iter=2000, warmup=1000, seed=20260407）
  - ✅ 所有borrowing参数已明确（a0=0.5, trim参数, cut_points）

- **output_contract.md**：标准输出结构
  - ✅ 定义了raw output和summary output格式
  - ⚠️ 待实现：metadata.json的正式生成与保存

#### 🆕 附加产物
本阶段还生成了以下支持文档：

- **alignment_checklist.md**：原型↔契约对齐检查单
  - 逐一核对Rmd原型是否与四份contract对齐
  - 追踪完整度与待修复清单
  - 为Step 0的最终验收提供checklist

- **step1_model_spec_template.md**：Step 1工作模板
  - 提前定义Step 1的交付物格式与内容结构
  - 包含estimand定义、模型框架、诊断规则等
  - 避免Step 0完成后才发现Step 1目标不清

---

### Step 0.5：对齐验证与优化

在正式冻结contract前，建议执行以下三项优先级任务：

#### 优先级 🔴 
1. **补齐分类变量编码规则**
   - 在input_contract.md中明确：sex, ecog, stage, biomarker的具体取值与编码
   - 从原始数据字典或业务规则中获取这些信息
   - 在Rmd中添加编码验证逻辑
   
2. **明确cont_y的定义**
   - 确定连续结局变量的实际含义、单位、取值范围
   - 更新input_contract.md
   - 在Rmd演示数据生成部分对齐

#### 优先级 🟡 
3. **配置完全外部化**
   - 创建`config/config_template.json`，包含所有当前硬编码参数
   - 修改Rmd，使其从config.json读取参数而非硬编码
   - 验证所有结果与原型一致

4. **规范化输出结构**
   - 为每次运行生成唯一的run_id
   - 创建metadata.json生成逻辑
   - 定义warnings收集机制

使用 `contracts/alignment_checklist.md` 中的"优先修复列表"作为工作指引。

---

### Step 1：明确统计模型
将当前 Rmd 中真正属于统计模型定义的部分抽取出来，明确：

- 模型目标
- 数据结构
- 参数定义
- likelihood
- prior
- borrowing mechanism
- estimand
- output summary 目标
- 诊断要求


---

### Step 2：转写 Stan-level model
在 step 1 冻结后，将统计模型正式转写为可独立运行的 Stan model，包括：

- data block
- parameters block
- model block
- generated quantities block

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

这个仓库当前正处于 **Step 0 完成 → Step 0.5 优化** 的阶段。建议的使用顺序：

### 第一步：理解整体框架
1. 阅读本 README 的"仓库目标"和"当前仓库内容"部分，了解项目的整体目标
2. 浏览四份contract文档，理解输入/输出/配置/预处理的边界定义
3. 查看原型Rmd，对应理解当前分析的实际实现

### 第二步：执行Step 0.5的改进任务（当前重点）
按照上文"Step 0.5"中的优先级清单，执行以下改进：
1. 🔴 补齐分类变量编码规则
2. 🔴 明确cont_y的定义
3. 🟡 配置外部化
4. 🟡 输出规范化

参考 `contracts/alignment_checklist.md` 来追踪完成进度。

### 第三步：推进Step 1（在Step 0.5完成后）
1. 基于 `docs/step1_model_spec_template.md` 的模板，正式撰写统计模型规范
2. 从原型Rmd中提取并冻结：estimand、模型方程式、prior设置、诊断规则

### 第四步：后续阶段（Step 2+）
只有在Step 1正式冻结后，才推进Stan转写、工程化等后续工作。

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
| 快速理解当前分析 | 读本README + 四份contract + Rmd原型 |
| 评审当前方法的合理性 | 查看step1_model_spec_template的框架，对应原型逐项检查 |
| 准备Stan迁移 | 完成Step 0.5后，填充step1_model_spec_template，生成冻结的统计模型定义 |
| 后续工程化对接 | 基于alignment_checklist的"优先修复列表"确保所有contract完整 |

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
│   └── step1_model_spec_template.md  （🆕 Step 1工作模板）
└── config/
    └── config_template.json          （🆕 标准config.json模板 - 所有参数冻结）