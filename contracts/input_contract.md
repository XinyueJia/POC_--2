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
- stage coding
- biomarker coding

### 5.3 单位
以下变量的单位必须固定：
- `time`：months（月份）
- `age`：years（年）
- `albumin`：g/L（克/升）
- `cont_y`：[待数据字典补充，应根据具体结局类型定义]

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