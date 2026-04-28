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

---

## 8. 原型（场景二-贝叶斯借用.Rmd）对应说明

### 8.1 当前实现状态

| 功能 | 状态 | 位置 | 说明 |
|---|---|---|---|
| model_name | ✅ | Rmd L1058 | 已定义为"borrowing_v1" |
| run_id生成 | ✅ | Rmd L1073-1076 | 时间戳格式：{model_name}_{YYYYMMDD_HHMMSS} |
| 诊断提取 | ✅ | Rmd L1225-1256 | 提取Rhat/ESS/divergent |
| metadata.json | ✅ | Rmd L1258-1273 | 包含运行参数和版本信息 |
| posterior draws | ✅ | Rmd L1350-1370 | 分别保存三种结局的draws |
| sampler_diagnostics | ✅ | Rmd L1372-1378 | 诊断汇总表 |
| summary_output.json | ✅ | Rmd L1380-1403 | 完整结果+诊断 |

### 8.2 输出文件清单（演示完成版）

运行后生成的文件结构：

```
outputs/
├── metadata.json              # 运行元信息（config + 时间戳）
├── summary_output.json        # 完整结果表（结果+诊断）
├── samples_binary.csv         # 二分类后验draws（raw output）
├── samples_continuous.csv     # 连续后验draws（raw output）
├── samples_survival.csv       # 生存后验draws（raw output）
└── sampler_diagnostics.csv   # 诊断指标汇总表
```

### 8.3 JSON 文件格式示例

**metadata.json:**
```json
{
  "run_id": "borrowing_v1_20260428_143022",
  "model_name": "borrowing_v1",
  "outcome_type": "multi-outcome",
  "analysis_date": "2026-04-28 14:30:22",
  "chains": 4,
  "iter": 2000,
  "warmup": 1000,
  "seed": 20260407,
  "a0": 0.5,
  "status": "success"
}
```

**summary_output.json:**
```json
{
  "run_id": "borrowing_v1_20260428_143022",
  "results": {
    "binary": {
      "result": {
        "outcome": "Binary",
        "effect": "OR",
        "post_mean": 0.404,
        "post_median": 0.397,
        "conf.low": 0.266,
        "conf.high": 0.585,
        "post_prob_benefit": 1.0
      },
      "diagnostics": {
        "outcome": "Binary",
        "rhat_max": 1.005,
        "ess_bulk_min": 920,
        "n_divergent": 0
      }
    }
  }
}
```