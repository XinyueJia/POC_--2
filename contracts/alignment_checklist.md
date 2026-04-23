# 原型 → Contract 对齐检查单（Alignment Checklist, v0.1）

本文档用于验证当前Rmd原型是否与四份contract对齐，并追踪完成状态。

---

## 1. Input Contract 对齐验证

### 1.1 必需字段覆盖
| 字段名 | 在Rmd中? | 编码规则已冻结? | 单位已明确? | 备注 |
|---|---|---|---|---|
| id | ✅ | ✅ | N/A | 原型中演示数据使用序列号 |
| source | ✅ | ✅ | N/A | 三个级别：Hainan_Treated, External_A, External_B |
| trt | ✅ | ✅ | N/A | 0/1编码 |
| age | ✅ | ✅ | ✅ | years（年） |
| sex | ✅ | ⚠️ | N/A | 编码方式在Rmd中定义为factor，具体水平值未明确文档化 |
| ecog | ✅ | ⚠️ | N/A | 编码方式未明确文档化 |
| stage | ✅ | ⚠️ | N/A | 编码方式未明确文档化 |
| biomarker | ✅ | ⚠️ | N/A | 编码方式未明确文档化 |
| prior_tx | ✅ | ⚠️ | N/A | 0/1编码 |
| albumin | ✅ | ✅ | ✅ | g/L（克/升） |
| time | ✅ | ✅ | ✅ | months（月份，从cut_points推断） |
| status | ✅ | ✅ | N/A | 0/1编码（0=删失，1=事件） |
| binary_y | ✅ | ✅ | N/A | 0/1编码 |
| cont_y | ✅ | ❌ | ❌ | 原型中为模拟数据，未明确实际含义与单位 |

### 1.2 缺失的明确编码规则
需要补充文档化的分类变量编码：
- [ ] sex：男/女具体编码（当前Rmd中使用factor但未明确水平顺序）
- [ ] ecog：ECOG等级的具体编码范围与含义（0, 1, 2, ...?)
- [ ] stage：分期的具体编码（如I, II, III, IV还是1, 2, 3, 4?）
- [ ] biomarker：生物标志物的编码方案（二分类/多分类?）

### 1.3 状态
**契约完整度：85%**  
待补充：cont_y的含义、部分分类变量的具体编码水平映射

---

## 2. Preprocessing Boundary 对齐验证

### 2.1 上游步骤在Rmd中的位置
| 步骤 | 在Rmd中实现? | 位置 | 责任方（当前） | 备注 |
|---|---|---|---|---|
| 数据读取 | ✅ | `read_analysis_data()` | R函数 | openxlsx读取 |
| 数据清洗 | ✅ | `read_analysis_data()` | R函数 | factor/类型转换 |
| 协变量编码 | ✅ | `read_analysis_data()` | R函数 | factor化 |
| PS估计 | ✅ | model chunk | WeightIt::weightit() | logistic regression |
| IPTW构造 | ✅ | `sw` 变量 | WeightIt | stabilized weights |
| trimming | ✅ | `trim_iptw_weights()` | R函数 | 分位数截尾 |
| source discount | ✅ | `source_discount` 变量 | Rmd逻辑 | a0参数应用 |
| survival split | ✅ | Stan data prep | Stan code | interval splitting |

### 2.2 Bayesian Engine步骤在Rmd中的位置
| 步骤 | 在Rmd中实现? | 使用的包 | 备注 |
|---|---|---|---|
| 模型拟合 | ✅ | brms | 结合了prior和likelihood |
| posterior sampling | ✅ | brms | 调用Stan backend |
| raw output生成 | ✅ | posterior | 提取draws和diagnostics |
| summary生成 | ✅ | 自定义R逻辑 | 计算CI、benefit prob等 |

### 2.3 状态
**边界对齐完整度：95%**  
待确认：后续从R迁移到独立Stan时，上游预处理的具体执行框架（谁负责实现脚本）

---

## 3. Config Contract 对齐验证

### 3.1 必需配置字段
| 字段 | 当前值 | 在Rmd中硬编码位置 | 已提取到config? | 备注 |
|---|---|---|---|---|
| model_name | borrowing_v1 | ❌ | ❌ | 建议在config中显式定义 |
| outcome_type | binary/continuous/survival | ❌ | ❌ | 当前在Rmd中由chunk选择 |
| a0 | 0.5 | 第1035行 | ✅ | 已在config示例中 |
| trim_lower | 0.01 | 第1036行 | ✅ | 已在config示例中 |
| trim_upper | 0.99 | 第1037行 | ✅ | 已在config示例中 |
| cut_points | [6,12,18,24,30] | 第1038行 | ✅ | 已在config示例中 |
| use_ps_weight | true | 隐含为TRUE | ✅ | 已在config示例中 |
| chains | 4 | 第1041行 | ✅ | 已在config示例中 |
| iter | 2000 | 第1042行 | ✅ | 已在config示例中 |
| warmup | 1000 | 第1043行 | ✅ | 已在config示例中 |
| seed | 20260407 | 第1045行 | ✅ | 已在config示例中 |

### 3.2 缺失的扩展字段
- [ ] `adapt_delta`：当前Rmd中未显式设置，brms使用默认值0.8
- [ ] `max_treedepth`：当前Rmd中未显式设置，brms使用默认值10
- [ ] `save_warmup`：当前Rmd中未显式设置
- [ ] 预处理参数映射：PS model formula、IPTW stability factor等是否应纳入config?

### 3.3 状态
**配置提取完整度：90%**  
待完成：
1. 将Rmd中硬编码的参数完全迁移到config JSON
2. 明确哪些预处理参数应该由config管理

---

## 4. Output Contract 对齐验证

### 4.1 Raw Output文件
| 文件 | 在Rmd中生成? | 格式 | 备注 |
|---|---|---|---|
| samples.csv | ✅ | brms posterior draws | 可由`as_draws_df()`提取 |
| sampler_diagnostics.csv | ✅ | brms diagnostics | 包含Rhat, ESS等 |
| run.log | ⚠️ | 文本 | 当前Rmd中消息输出未正式保存 |
| metadata.json | ❌ | JSON | 当前无正式metadata文件 |

### 4.2 Summary Output字段
| 字段 | 在Rmd中生成? | 计算方式 | 备注 |
|---|---|---|---|
| run_id | ❌ | | 建议添加 |
| model_name | ❌ | | 建议添加 |
| outcome_type | ✅ | 在chunk中定义 | 已计算 |
| estimand | ✅ | OR/MD/HR | 已计算 |
| posterior_mean | ✅ | brms摘要 | 已提取 |
| posterior_median | ✅ | brms摘要 | 已提取 |
| ci_95_lower | ✅ | credible interval | 已计算 |
| ci_95_upper | ✅ | credible interval | 已计算 |
| benefit_probability | ✅ | P(effect > 0) | 已计算 |
| rhat_max | ✅ | diagnostics | 已计算 |
| ess_bulk_min | ✅ | diagnostics | 已计算 |
| n_divergent | ✅ | sampler diagnostics | 已计算 |
| warnings | ⚠️ | 文本 | 当前未正式收集 |

### 4.3 状态
**输出对齐完整度：85%**  
待完成：
1. 正式化raw output文件保存（特别是metadata.json）
2. 为每次运行生成run_id并追踪
3. 收集并正式化warnings

---

## 5. 总体对齐状态

| Contract | 完整度 | 优先级 | 下一步行动 |
|---|---|---|---|
| Input | 85% | 🔴 | 补齐分类变量编码规则、cont_y含义 |
| Preprocessing Boundary | 95% | 🟡 | 明确预处理框架与责任边界 |
| Config | 90% | 🟡 | 完整提取所有参数到config JSON |
| Output | 85% | 🟡 | 正式化metadata和warnings收集 |

---

## 6. 优先修复列表（按顺序）

### 优先级 1：冻结分类变量编码
**目标**：Step 0完成前必须完成  
**任务**：
- [ ] 从原始数据或业务规则文档中获取sex, ecog, stage, biomarker的具体编码
- [ ] 更新input_contract.md的第4.2-4.4部分，明确所有分类变量的编码规则
- [ ] 在Rmd中添加编码验证逻辑（assert对因子水平）

### 优先级 2：配置完全外部化
**目标**：支持从config.json驱动Rmd或后续Stan脚本  
**任务**：
- [ ] 创建标准的config.json文件模板
- [ ] 在Rmd开头添加config读取逻辑
- [ ] 验证所有运行参数都来自config而非硬编码

### 优先级 3：规范化输出结构
**目标**：为Step 2（Stan转写）准备标准输出框架  
**任务**：
- [ ] 添加metadata.json生成逻辑
- [ ] 创建run_id生成规则
- [ ] 定义warnings收集和保存逻辑

---

## 7. 验证者签名

| 角色 | 名字 | 日期 | 备注 |
|---|---|---|---|
| 统计分析 | | | |
| 工程实现 | | | |
| 审核 | | | |

---

## 8. 相关文档
- [input_contract.md](./input_contract.md)
- [preprocessing_boundary.md](./preprocessing_boundary.md)
- [config_contract.md](./config_contract.md)
- [output_contract.md](./output_contract.md)
- [场景二-贝叶斯借用.Rmd](../prototype/场景二-贝叶斯借用.Rmd)
