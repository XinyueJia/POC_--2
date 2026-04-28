# Step 1 工作模板：统计模型规范（Statistical Model Specification Template, v0.2）

本文档用于冻结当前原型 Rmd 的统计模型定义，作为后续 Stan 转写的唯一参考版本。

**冻结范围**：当前单臂试验 + 多来源外部对照的三类结局分析；
**冻结原则**：与 [prototype/场景二-贝叶斯借用.Rmd](/Users/xinyuejia/Projects/POC_场景2/prototype/%E5%9C%BA%E6%99%AF%E4%BA%8C-%E8%B4%9D%E5%8F%B6%E6%96%AF%E5%80%9F%E7%94%A8.Rmd) 和 [config/config.json](/Users/xinyuejia/Projects/POC_场景2/config/config.json) 保持一致。

---

## 1. 模型元信息

| 项目 | 内容 |
|---|---|
| 模型名称 | `borrowing_v1` |
| 版本 | v0.2 |
| 结局类型 | binary / continuous / survival |
| 更新日期 | |
| 审核人 | |

---

## 2. 研究目标与Estimand

### 2.1 主要研究目标
利用 IPTW 与 fixed power prior 结合多来源外部对照，对单臂试验治疗组相对于外部对照的疗效进行估计，并分别针对生存、二分类和连续结局报告后验效应量。

### 2.2 Estimand定义
[明确下列内容]

**For binary outcome:**
-- Estimand：Odds Ratio (OR)
- 参考组（baseline）：Control (trt=0)
- 对比组：Treated (trt=1)
- 群体：整体分析人群

**For continuous outcome:**
-- Estimand：Mean Difference (MD)
- 参考组：Control (trt=0)
- 对比组：Treated (trt=1)

**For survival outcome:**
- Estimand：Hazard Ratio (HR)
- 参考组：Control (trt=0)
- 对比组：Treated (trt=1)
- 时间点：Overall survival、event-free survival?

### 2.3 次要目标
- 报告 95% credible interval
- 报告 posterior mean / median
- 报告后验获益概率 $P(\text{benefit} \mid \text{data})$
- 比较有无 IPTW 与有无 borrowing 时的结果稳定性

---

## 3. 数据结构

### 3.1 分析人群
最终分析人群为三来源合并样本：
- Hainan_Treated cohort: N = 200
- External_A cohort: N = 260
- External_B cohort: N = 240
- Total: N = 700

### 3.2 数据关键维度
| 维度 | 说明 |
|---|---|
| 个体级记录 | 1 row per subject |
| 主键 | id |
| 分组变量 | source (data origin), trt (treatment) |
| 协变量 | age, sex, ecog, stage, biomarker, prior_tx, albumin |
| 结局变量 | time/status (survival) 或 binary_y 或 cont_y |

### 3.3 协变量列表
用于 PS 模型与频率学回归调整的协变量如下；Bayesian borrowing 结局模型仅保留 `trt`，生存结局额外保留 `interval` 和 offset。

| 变量名 | 类型 | 用途 | 编码/单位 |
|---|---|---|---|
| age | continuous | PS model, covariate adjustment | years |
| sex | binary/categorical | PS model, covariate adjustment | Female/Male |
| ecog | ordinal | PS model, covariate adjustment | 0/1/2 |
| stage | binary/categorical | PS model, covariate adjustment | III/IV |
| biomarker | binary/categorical | PS model, covariate adjustment | Negative/Positive |
| prior_tx | binary | PS model, covariate adjustment | No/Yes |
| albumin | continuous | PS model, covariate adjustment | g/L |

---

## 4. 模型框架

### 4.1 总体模型结构
当前原型采用两层结构：
1. **Weighting model**: $W_i = \text{IPTW}_i^{\text{trim}} \times d_i$
2. **Outcome model**: 在加权样本上分别拟合 binary / continuous / survival 结局模型

其中，$d_i = 1$（治疗组）或 $a_0$（外部对照），并通过 `brms::brm()` 进行 Bayesian 推断。

### 4.2 Binary Outcome Model

#### 4.2.1 Likelihood
$$
Y_i \mid W_i, \theta \sim \text{Bernoulli}(p_i)
$$

$$
	ext{logit}(p_i) = \alpha + \beta_{\text{trt}} \cdot \text{trt}_i
$$

#### 4.2.2 加权（Weighting）

第 $i$ 个个体的分析权重定义为：

$$
W_i = \mathrm{IPTW}_i \times d_i
$$

其中，$\text{IPTW}_i^{\text{trim}}$ 为稳定化 IPTW 经分位数截尾后的权重，$d_i$ 为数据来源折扣因子。

当前原型中，治疗组取 $d_i = 1$，外部对照取 $d_i = a_0$，且 $a_0 = 0.5$。

$$
d_i =
\begin{cases}
1, & \text{若 } \mathrm{source}_i = \text{Hainan\_Treated}, \\
a_0, & \text{若 } \mathrm{source}_i \in \{\text{External\_A}, \text{External\_B}\} \text{ 且 } A_i = 0.
\end{cases}
$$

其中，$a_0 \in [0, 1]$ 用于控制外部对照数据的信息借用强度（information borrowing strength）。

### 4.3 Continuous Outcome Model

#### 4.3.1 Likelihood
$$
Y_i \mid W_i, \theta \sim N(\mu_i, \sigma^2)
$$

$$
\mu_i = \alpha + \beta_{\text{trt}} \cdot \text{trt}_i
$$

#### 4.3.2 权重
与 binary 结局相同：$W_i = \text{IPTW}_i^{\text{trim}} \times d_i$。

### 4.4 Survival Outcome Model

#### 4.4.1 数据展开
生存结局先通过 `survSplit()` 切分为 piecewise exponential 数据集：

$$
N_{ij} \sim \text{Poisson}(\mu_{ij})
$$

$$
\log(\mu_{ij}) = \log(t_{ij}) + \alpha_j + \beta_{\text{trt}} \cdot \text{trt}_i
$$

其中 $\alpha_j$ 为分段基线对数风险，$t_{ij}$ 为该区间暴露时间。

#### 4.4.2 权重
与 binary / continuous 结局相同：$W_i = \text{IPTW}_i^{\text{trim}} \times d_i$。

---

## 5. 借用机制（Borrowing Mechanism）

### 5.1 Borrowing方法
当前原型采用 fixed power prior 风格的外部对照折扣借用，但实现上通过观测层权重完成：
- 治疗组：权重保持为 `IPTW_trim`
- 外部对照：权重为 `IPTW_trim × a0`

因此，借用强度由 $a_0$ 直接控制，而不是在参数先验上额外引入层级随机效应。

### 5.2 折扣参数（Discount Parameter）

#### 5.2.1 参数设置
- **参数名**：$a_0$
- **当前值**：0.5
- **适用范围**：外部对照群的Bayesian权重折扣
- **设计依据**：当前原型使用固定折扣值作为默认工作点，后续如需可再做敏感性分析

#### 5.2.2 参数变异性
- [x] $a_0$ 为固定值
- [ ] 是否计划进行敏感性分析（vary $a_0$）
- 若后续扩展，考虑的 $a_0$ 范围：0.3 / 0.5 / 0.7

### 5.3 预处理权重整合

权重计算流程：
1. 估计propensity score: $P(\text{trt} = 1 | X)$
2. 计算IPTW（stabilized）
3. 应用分位数截尾：trim_lower=0.01, trim_upper=0.99
4. 乘以source discount: $W = \text{IPTW}_{\text{trim}} \times d_i$
5. 传入Bayesian模型作为case weight

---

## 6. 诊断与评估规则

### 6.1 收敛诊断
| 诊断指标 | 可接受标准 | 检查方法 |
|---|---|---|
| Rhat | < 1.05 | 比较chain间方差与chain内方差 |
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
- 三类结局的效应量：OR / MD / HR

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
- [x] 改变trimming参数
- [x] 改变prior设置

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

### 9.6 Bayesian prior 设置
```
priors_binary <- c(
	brms::set_prior("normal(0, 2.5)", class = "Intercept"),
	brms::set_prior("normal(0, 2.5)", class = "b")
)

priors_cont <- c(
	brms::set_prior("normal(0, 10)", class = "Intercept"),
	brms::set_prior("normal(0, 10)", class = "b"),
	brms::set_prior("student_t(3, 0, 10)", class = "sigma")
)

priors_surv <- c(
	brms::set_prior("normal(0, 2.5)", class = "Intercept"),
	brms::set_prior("normal(0, 2.5)", class = "b")
)
```

### 9.7 Outcome model 公式
```
binary_y | weights(bayes_w) ~ trt
cont_y   | weights(bayes_w) ~ trt
event_piece | weights(bayes_w) ~ trt + interval + offset(log(exposure))
```

---

## 10. 待完成清单

**完成前不应进入Step 2（Stan转写）**

- [x] 确认estimand的正式定义
- [x] 确认所有协变量的编码规则
- [x] 确认prior分布的具体形式与超参数
- [x] 确认借用机制的数学表达式
- [x] 确认与原型Rmd的一致性

---

## 11. 版本历史

| 版本 | 日期 | 改动 | 审核人 |
|---|---|---|---|
| v0.2 | 2026-04-28 | Frozen to current Rmd prototype | XJ |

