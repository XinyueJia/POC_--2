# 输入契约（Input Contract, v0.1）

## 1. 目的
本文档用于定义 Bayesian borrowing 分析流程的标准输入数据格式。

本版本基于当前原型脚本：
- 场景二-贝叶斯借用.Rmd

目标是确保后续所有步骤都基于一套固定且共享的输入契约开展工作。

---

## 2. 输入文件

### 文件名
`input_analysis.csv`

### 每一行表示
1 名受试者 / 1 条个体级记录。

### 主键
`id`

### 说明
- 所有数据清洗与重编码必须在数据进入 Bayesian workflow 之前完成。
- 缺失值处理必须在上游完成。
- Stan / CmdStan **不直接读取**原始源数据表。

---

## 3. 必需字段

| 字段名 | 类型 | 必填 | 允许取值 / 格式 | 含义 | 用途 |
|---|---|---:|---|---|---|
| id | string / int | 是 | 唯一值 | 个体唯一标识 | 全部 |
| source | string | 是 | `Hainan_Treated`, `External_A`, `External_B` | 数据来源 | weighting / borrowing |
| trt | int | 是 | `0`, `1` | treatment indicator | 全部 outcome model |
| age | numeric | 是 | 实数 | 年龄 | PS model |
| sex | string / int | 是 | 固定编码 | 性别 | PS model |
| ecog | int | 是 | 例如 `0,1,2,...` | ECOG 评分 | PS model |
| stage | string / int | 是 | 固定编码 | 分期 | PS model |
| biomarker | numeric / int / string | 是 | 固定编码 | 生物标志物状态/数值 | PS model |
| prior_tx | int | 是 | `0`, `1` | 既往治疗 | PS model |
| albumin | numeric | 是 | 实数 | 白蛋白 | PS model |
| time | numeric | 条件必填 | 正实数 | 生存时间 | survival model |
| status | int | 条件必填 | `0`, `1` | 事件指示变量 | survival model |
| binary_y | int | 条件必填 | `0`, `1` | 二分类结局 | binary model |
| cont_y | numeric | 条件必填 | 实数 | 连续型结局 | continuous model |

---

## 4. 冻结语义（Frozen Semantics）

以下字段含义在本版本中必须保持固定。

### 4.1 `source`
- `Hainan_Treated`：内部 treated cohort
- `External_A`：外部对照来源 A
- `External_B`：外部对照来源 B

### 4.2 `trt`
- `trt = 1`：treated
- `trt = 0`：control

### 4.3 `status`
- `status = 1`：发生事件
- `status = 0`：删失（censored）

### 4.4 `binary_y`
- `binary_y = 1`：有利结局 / response
- `binary_y = 0`：无 response / 不利结局

> 若团队后续决定采用相反编码，必须升级版本号。

---

## 5. 数据类型与编码规则

### 5.1 总体规则
所有分类变量在进入 Stan / CmdStan workflow 之前，必须已经完成编码。

### 5.2 必须固定的编码项
以下编码方式在部署前必须明确并文档化：
- sex coding
- ecog coding
- stage coding
- biomarker coding
- prior_tx coding

### 5.3 单位
以下变量的单位必须固定：
- `time`：months（月份）
- `age`：years（年）
- `albumin`：g/L（克/升）
- `cont_y`：演示阶段无特定单位；实际应用时应根据具体结局类型定义

### 5.4 通用演示变量说明

#### biomarker（生物标志物状态）

**设计阶段地位**：通用演示变量，不绑定具体临床指标

**当前编码方案**（模拟数据中）：
- `biomarker = 0`：Negative（阴性）
- `biomarker = 1`：Positive（阳性）

**实际应用映射**（后续接入真实数据时）：
- 可代表：PD-L1表达、MSI/dMMR状态、特定基因突变、蛋白表达水平等
- 可为二分类（阳/阴）、多分类（低/中/高表达）、或连续值
- **关键约束**：与PS model兼容（当前假设为离散变量）
- **迁移规则**：替换时应在input_contract更新版本号，明确新指标的编码和临床含义

#### cont_y（连续型结局示例）

**设计阶段地位**：通用演示变量，展示"连续结局的分析方法"而非特定指标

**当前特征**（模拟数据中）：
- 均值约55，标准差约6（正态分布）
- 无特定单位，用于演示线性回归模型

**实际应用映射**（后续接入真实数据时）：
- 可代表：生化标志物浓度（CEA、PSA等）、影像测量（肿瘤直径mm、体积cm³）、功能评分（生活质量评分）、生理指标（血压mmHg、血糖mg/dL）等
- **关键约束**：模型假设近似正态分布。若实际指标存在明显偏态或非线性关系，需在上游进行变量转换（log/sqrt）或采用分位数回归
- **迁移规则**：替换时应在input_contract中明确新指标的单位、取值范围、临床定义、以及是否需要变量转换

#### sex（性别）

**设计阶段地位**：标准分类变量（二分类）

**当前编码方案**（演示数据中）：
- `sex = 0`：Female（女性）
- `sex = 1`：Male（男性）

**关键约束**：
- 二进制编码（必须为0/1，不支持多分类或缺失值）
- 与 PS model 兼容
- 实际应用中不应改变编码方向，若需要，必须升级版本号

---

#### ecog（ECOG 体能状态评分）

**设计阶段地位**：有序分类变量

**当前编码方案**（演示数据中）：
- `ecog = 0`：完全活动（Fully active）
- `ecog = 1`：限制剧烈活动（Restricted in strenuous activity）
- `ecog = 2`：卧床 <50%（In bed <50% of day）
- 当前原型不包含 ecog = 3/4（因为这样的患者通常被排除在研究外）

**关键约束**：
- 整数编码（0, 1, 2, ...）且应是连续的
- 数值顺序应反映临床严重程度升序
- 与 PS model 兼容（当前 brms 将其视为无序因子）

---

#### stage（分期）

**设计阶段地位**：无序分类变量

**当前编码方案**（演示数据中）：
- `stage = "III"`：III 期
- `stage = "IV"`：IV 期
- 当前原型不包含 I/II 期（因为晚期队列研究通常只招募 III/IV）

**关键约束**：
- 字符向量形式（"III", "IV"）
- 不支持罗马数字混写（如 "3" vs "III" 混用）
- 若实际应用需要分阶段（如 IIIA vs IIIB），必须在 input_contract 中升级版本号并明确新编码规则
- 与 PS model 兼容（brms 自动因子化处理）

---

#### prior_tx（既往治疗）

**设计阶段地位**：标准分类变量（二分类）

**当前编码方案**（演示数据中）：
- `prior_tx = 0`：无既往系统治疗（No prior systemic therapy）
- `prior_tx = 1`：有既往系统治疗（Any prior systemic therapy）

**关键约束**：
- 二进制编码（必须为0/1）
- 当前表示"有/无"二元状态
- 若后续需要细分治疗线数或特定治疗类型，应升级为多分类变量并更新版本号

---

## 6. 上游与下游边界

### 上游（进入 Stan / CmdStan 之前）
以下步骤必须在上游完成：
- 原始数据读取
- 数据清洗
- 类型转换
- 分类变量重编码
- 缺失值处理
- propensity score 估计
- weight 构造
- trimmed weight 计算
- source discount 应用
- survival interval splitting（如需要）

### 下游（Stan / CmdStan）
Stan / CmdStan 仅负责：
- Bayesian model fitting
- posterior sampling
- posterior raw output 生成

---

## 7. 最小示例记录

```csv
id,source,trt,age,sex,ecog,stage,biomarker,prior_tx,albumin,time,status,binary_y,cont_y
1,Hainan_Treated,1,62,M,1,III,1,0,38.2,14.3,1,1,72.5
```

---

## 8. 版本规则
以下任一内容发生变化时，必须触发 contract version 更新：
- 字段名
- 编码方式
- level 含义
- 单位
- 必填 / 选填状态