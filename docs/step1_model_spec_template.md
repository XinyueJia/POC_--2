# Step 1 工作模板：统计模型规范（Statistical Model Specification Template, v0.1）

本文档是Step 1的工作模板，用于从原型Rmd中提取并冻结统计模型的正式定义。

---

## 1. 模型元信息

| 项目 | 内容 |
|---|---|
| 模型名称 | `borrowing_v1` |
| 版本 | v0.1 |
| 结局类型 | binary / continuous / survival（待选择） |
| 更新日期 | |
| 审核人 | |

---

## 2. 研究目标与Estimand

### 2.1 主要研究目标
[从Rmd原型的引言部分抽取]

例如：
- 利用外部对照数据通过Bayesian borrowing方法，提高单臂试验对照的统计效率
- 评估新疗法相对于并借用外部对照的治疗效应

### 2.2 Estimand定义
[明确下列内容]

**For binary outcome:**
- Estimand：Odds Ratio (OR) / Risk Ratio (RR) / Risk Difference (RD) ?
- 参考组（baseline）：Control (trt=0)
- 对比组：Treated (trt=1)
- 群体：Overall / Subgroup?

**For continuous outcome:**
- Estimand：Mean Difference (MD) / Ratio of Means?
- 参考组：Control (trt=0)
- 对比组：Treated (trt=1)

**For survival outcome:**
- Estimand：Hazard Ratio (HR)
- 参考组：Control (trt=0)
- 对比组：Treated (trt=1)
- 时间点：Overall survival、event-free survival?

### 2.3 次要目标
[列出所有次要endpoint和target estimand]

---

## 3. 数据结构

### 3.1 分析人群
[描述最终分析人群的定义和样本量]

例如：
- Hainan_Treated cohort: N1 subjects
- External_A cohort: N2 subjects
- External_B cohort: N3 subjects
- Total: N subjects for analysis

### 3.2 数据关键维度
| 维度 | 说明 |
|---|---|
| 个体级记录 | 1 row per subject |
| 主键 | id |
| 分组变量 | source (data origin), trt (treatment) |
| 协变量 | age, sex, ecog, stage, biomarker, prior_tx, albumin |
| 结局变量 | time/status (survival) 或 binary_y 或 cont_y |

### 3.3 协变量列表
[完整列出所有用于PS模型或Bayesian模型中的协变量]

| 变量名 | 类型 | 用途 | 编码/单位 |
|---|---|---|---|
| age | continuous | PS model, covariate adjustment | years |
| sex | binary/categorical | PS model, covariate adjustment | |
| ecog | ordinal | PS model, covariate adjustment | |
| stage | ordinal | PS model, covariate adjustment | |
| biomarker | binary/categorical | PS model, covariate adjustment | |
| prior_tx | binary | PS model, covariate adjustment | 0/1 |
| albumin | continuous | PS model, covariate adjustment | g/L |

---

## 4. 模型框架

### 4.1 总体模型结构
[描述模型的分层结构]

通常采用三层结构：
1. **Outcome model**: P(Y | X, W, trt, source)
2. **Weighting model**: W = IPTW × source_discount
3. **Prior specification**: π(θ)

### 4.2 Binary Outcome Model

#### 4.2.1 Likelihood
$$
Y_i | X_i, W_i, \theta \sim \text{Bernoulli}(p_i)
$$

$$
\text{logit}(p_i) = \alpha + \beta_{\text{trt}} \cdot \text{trt}_i + \sum_k \beta_k \cdot X_{k,i}
$$

#### 4.2.2 Weighting
$$
W_i = \text{IPTW}_i \times \text{source\_discount}_i
$$

其中：
- $\text{IPTW}_i = \frac{\mathbb{1}[\text{trt}_i = 1]}{P(\text{trt}_i = 1 | X_i)} + \frac{\mathbb{1}[\text{trt}_i = 0]}{P(\text{trt}_i = 0 | X_i)}$（stabilized）
- $\text{source\_discount}_i = \begin{cases} 1 & \text{if } \text{source}_i = \text{Hainan\_Treated} \\ a_0 & \text{if } \text{source}_i \in \{\text{External\_A}, \text{External\_B}\} \text{ and } \text{trt}_i = 0 \end{cases}$

#### 4.2.3 Prior Specification
| 参数 | Prior分布 | 超参数 | 理由 |
|---|---|---|---|
| $\alpha$ | | | |
| $\beta_{\text{trt}}$ | | | |
| $\beta_k$ (other) | | | |

[从Rmd原型中提取当前使用的prior；如无明确设置则说明brms默认]

### 4.3 Continuous Outcome Model
[类似结构，替换为线性模型和高斯likelihood]

### 4.4 Survival Outcome Model
[描述interval-censored或Weibull等参数化survival模型的结构]

---

## 5. 借用机制（Borrowing Mechanism）

### 5.1 Borrowing方法
[描述具体使用的借用方法]

例如：
- Power Prior with external control discount
- Commensurate Prior
- Hierarchical model with source-specific variance

### 5.2 折扣参数（Discount Parameter）

#### 5.2.1 参数设置
- **参数名**：$a_0$
- **当前值**：0.5
- **适用范围**：外部对照群的Bayesian权重折扣
- **设计依据**：[说明为什么选择0.5]

#### 5.2.2 参数变异性
- [ ] $a_0$是固定值还是随机变量?
- [ ] 是否计划进行敏感性分析（vary $a_0$)?
- 若是，考虑的$a_0$范围：[0.3, 0.5, 0.7, ...]?

### 5.3 预处理权重整合

权重计算流程：
1. 估计propensity score: $P(\text{trt} = 1 | X)$
2. 计算IPTW（stabilized）
3. 应用分位数截尾：trim_lower=0.01, trim_upper=0.99
4. 乘以source discount: $W = \text{IPTW}_{\text{trim}} \times a_0^{\text{source}}$
5. 传入Bayesian模型作为case weight

---

## 6. 诊断与评估规则

### 6.1 收敛诊断
| 诊断指标 | 可接受标准 | 检查方法 |
|---|---|---|
| Rhat | < 1.01 | 比较chain间方差与chain内方差 |
| Bulk ESS | > 400（per chain）| 有效样本量评估 |
| Tail ESS | > 400（per chain）| 尾部有效样本量 |
| Divergent transitions | = 0 | 检查树深度违反 |

### 6.2 先验拟合诊断
[如适用，列出prior sensitivity check的计划]

### 6.3 借用诊断
[列出评估借用有效性的方法]

例如：
- 比较有借用 vs 无借用情景下的后验宽度
- 计算有效样本量的变化
- 检查外部数据对后验的影响

---

## 7. 输出与总结

### 7.1 主要输出
[列出需要报告的所有posterior推断结果]

- Posterior mean, median
- 95% credible interval
- P(effect > 0) / benefit probability
- 诊断统计量

### 7.2 Secondary outputs
[列出补充性输出]

例如：
- Posterior draws用于进一步计算
- 治疗效应的异质性估计（如有subgroup analysis）

---

## 8. 模型验证计划

### 8.1 内部验证
- [ ] 先验预测分布检查
- [ ] 后验预测分布检查
- [ ] 参数恢复（如使用模拟数据）

### 8.2 灵敏度分析
- [ ] 改变折扣参数$a_0$的值
- [ ] 改变trimming参数
- [ ] 改变prior设置

### 8.3 对比分析
- [ ] 与频率主义方法的对比
- [ ] 与无借用Bayesian模型的对比

---

## 9. 从原型Rmd提取的关键代码片段

### 9.1 PS模型公式
```
ps_formula <- trt ~ age + sex + ecog + stage + biomarker + prior_tx + albumin
```

### 9.2 权重截尾参数
```
trim_lower  <- 0.01
trim_upper  <- 0.99
```

### 9.3 Survival cut points
```
cut_points  <- c(6, 12, 18, 24, 30)
```

### 9.4 MCMC设置
```
chains  <- 4
iter    <- 2000
warmup  <- 1000
seed    <- 20260407
```

### 9.5 Borrowing参数
```
a0      <- 0.5
```

[需要从Rmd中补充：brms的prior设置代码]

---

## 10. 待完成清单

**完成前不应进入Step 2（Stan转写）**

- [ ] 确认estimand的正式定义
- [ ] 确认所有协变量的编码规则
- [ ] 确认prior分布的具体形式与超参数
- [ ] 确认借用机制的数学表达式
- [ ] 获得统计审核的签字
- [ ] 确认与原型Rmd的一致性

---

## 11. 版本历史

| 版本 | 日期 | 改动 | 审核人 |
|---|---|---|---|
| v0.1 | | Initial template | |

