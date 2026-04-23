# 预处理边界（Preprocessing Boundary, v0.1）

## 1. 目的
本文档用于定义哪些步骤属于：
- 上游预处理（upstream preprocessing）
以及哪些步骤属于
- Bayesian inference execution

该边界在当前 workflow 中必须保持固定。

---

## 2. 基本原则
Bayesian engine 不负责原始数据清洗，也不负责具体研究场景下的数据预处理。

Bayesian engine 默认输入的是已经准备好的 analysis-ready data。

---

## 3. 上游步骤（Stan / CmdStan 之外）

在调用 Bayesian engine 之前，以下步骤必须已经完成：

### 3.1 数据读取
- 读取原始数据
- 如有需要，合并不同来源数据
- 选择 analysis population

### 3.2 数据清洗
- 类型转换
- factor / level 规范化
- 缺失值处理
- 非法值过滤

### 3.3 协变量准备
- treatment indicator 编码
- source 编码
- covariate 重编码
- 单位统一

### 3.4 Propensity score 与 weighting
- 估计 propensity scores
- 构造 stabilized IPTW
- 应用 trimming
- 应用 source-specific discount
- 构造最终 Bayesian analysis weight

### 3.5 Survival 预处理
如果使用 survival analysis，则还需要：
- 定义 cut points
- 必要时对 follow-up 进行 interval splitting
- 构造 interval / exposure / event-piece 输入

---

## 4. Bayesian Engine 步骤（Stan / CmdStan 之内）

Bayesian engine 负责：

### 4.1 模型拟合
- 读取模型输入
- 评估 prior + likelihood
- 执行 posterior sampling

### 4.2 Raw output 生成
- posterior draws
- diagnostics
- run metadata

### 4.3 下游 summary 生成
- 提取效应量
- 计算区间
- 计算 benefit probability
- 汇总诊断指标

---

## 5. 当前原型中的冻结边界

对于当前原型，以下步骤明确位于 Stan 之外：
- propensity score model
- IPTW 构造
- trimming
- source discount
- 最终 weight 计算

Stan / CmdStan 接收的是已经准备好的 Bayesian fitting 输入。

---

## 6. 为什么要冻结这一边界
冻结这一边界的目的在于：
- 简化实现
- 简化与工程团队 / 加密团队的协作
- 避免将统计预处理与 Bayesian inference runtime 混杂
- 支持未来逐步脱离 R-bound workflow

---

## 7. 责任方与实现框架

### 7.1 当前原型中的实现方
在当前R-based原型中，所有预处理步骤均在Rmd中实现，主要由统计分析人员负责：

| 步骤 | 当前实现 | R函数/包 | 负责方 |
|---|---|---|---|
| 数据读取 | Rmd chunk | openxlsx::read.xlsx() | 统计分析 |
| 数据清洗 | Rmd chunk | dplyr | 统计分析 |
| 协变量编码 | `read_analysis_data()` | base R factors | 统计分析 |
| PS估计 | Rmd chunk | WeightIt::weightit() | 统计分析 |
| IPTW构造 | Rmd chunk | WeightIt (stabilized) | 统计分析 |
| trimming | `trim_iptw_weights()` | base R | 统计分析 |
| source discount | Rmd逻辑 | base R | 统计分析 |
| survival split | Stan data prep | Stan code | 统计分析 |

### 7.2 后续工程化阶段的责任划分
在Step 2及之后，预处理可能由独立脚本或工程框架实现：

- **配置驱动**：所有预处理参数从config.json读取
- **独立脚本**：预处理可能迁移到Python/R standalone脚本（与Stan解耦）
- **工程团队**：若实施工程化封装，工程团队负责将预处理集成至pipeline
- **加密团队**：若实施安全执行，预处理可能需要支持加密/MPC兼容输入

---

## 8. 后续变更
若团队后续决定将某些预处理步骤迁入 secure execution engine，则必须作为新的 boundary version 进行记录。