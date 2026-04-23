# 输出契约（Output Contract, v0.1）

## 1. 目的
本文档用于定义 Bayesian borrowing workflow 的标准输出结构。

输出分为两层：
1. raw output
2. summary output

这一区分在本流程中是强制要求。

---

## 2. Raw Output

### 2.1 定义
raw output 指 Bayesian engine 直接生成的采样输出与运行元数据。

### 2.2 标准 raw output 文件

| 文件名 | 含义 |
|---|---|
| `samples.csv` | posterior draws |
| `sampler_diagnostics.csv` | sampler diagnostics |
| `run.log` | 运行日志 |
| `metadata.json` | 运行元信息 |

### 2.3 冻结规则
raw output 必须保留，不能只保留 summary 而丢弃 raw output。

---

## 3. Metadata 结构

### 示例
```json
{
  "run_id": "demo_001",
  "model_name": "borrowing_v1",
  "outcome_type": "binary",
  "input_file": "input_analysis.csv",
  "config_file": "config.json",
  "chains": 4,
  "iter": 2000,
  "warmup": 1000,
  "seed": 20260407,
  "status": "success"
}
```

---

## 4. Summary Output

### 4.1 作用
summary output 是返回给下游用户、GUI 或平台服务的标准化结果。

### 4.2 标准字段

| 字段名 | 类型 | 含义 |
|---|---|---|
| run_id | string | 本次运行唯一标识 |
| model_name | string | 模型标识 |
| outcome_type | string | binary / continuous / survival |
| estimand | string | OR / Mean difference / HR |
| posterior_mean | numeric | posterior mean |
| posterior_median | numeric | posterior median |
| ci_95_lower | numeric | 95% credible interval 下界 |
| ci_95_upper | numeric | 95% credible interval 上界 |
| benefit_probability | numeric | posterior benefit probability |
| rhat_max | numeric | 监测参数中的最大 R-hat |
| ess_bulk_min | numeric | 最小 bulk ESS |
| n_divergent | int | divergent transition 数量 |
| warnings | array / string | 本次运行产生的警告信息 |

### 4.3 示例
```json
{
  "run_id": "demo_001",
  "model_name": "borrowing_v1",
  "outcome_type": "binary",
  "estimand": "OR",
  "posterior_mean": 0.404,
  "posterior_median": 0.397,
  "ci_95_lower": 0.266,
  "ci_95_upper": 0.585,
  "benefit_probability": 1.000,
  "rhat_max": 1.01,
  "ess_bulk_min": 820,
  "n_divergent": 0,
  "warnings": []
}
```

---

## 5. Summary 规则

### 5.1 必须报告的内容
每个 summary output 必须包括：
- 点估计
- 区间估计
- posterior benefit probability
- 关键诊断指标

### 5.2 不同结局对应的 estimand
- binary outcome：`OR`
- continuous outcome：`Mean difference`
- survival outcome：`HR`

### 5.3 诊断规则
若缺少诊断字段，则结果不能视为完整可报告结果。

---

## 6. Plot Output（v0.1 中可选）
本版本尚未冻结 plot output。

若后续需要标准化 plot，应由以下之一生成：
- raw posterior draws
或
- summary output + 固定 plot specification

---

## 7. 版本规则
以下任一内容发生变化时，必须触发新的 output contract version：
- 输出字段名
- 区间定义
- estimand 定义
- 诊断要求