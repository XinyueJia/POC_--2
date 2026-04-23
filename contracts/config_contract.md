# 配置契约（Config Contract, v0.1）

## 1. 目的
本文档用于定义 Bayesian borrowing workflow 的标准运行配置（runtime configuration）。

目的在于分离：
- model / data input
与
- runtime / analysis configuration

所有运行参数都必须显式存放于 config file 中，而不是硬编码在脚本中。

---

## 2. 配置文件

### 文件名
`config.json`

### 作用
用于定义固定的分析设置与 MCMC runtime settings。

---

## 3. 必需字段

| 字段名 | 类型 | 示例 | 含义 |
|---|---|---|---|
| model_name | string | `borrowing_v1` | 模型标识 |
| outcome_type | string | `binary` / `continuous` / `survival` | 结局类型 |
| a0 | numeric | `0.5` | external control discount factor |
| trim_lower | numeric | `0.01` | weight trimming 下分位点 |
| trim_upper | numeric | `0.99` | weight trimming 上分位点 |
| cut_points | numeric array | `[6,12,18,24,30]` | survival model 分段点 |
| use_ps_weight | boolean | `true` | 是否使用 PS-based weighting |
| chains | int | `4` | MCMC 链数 |
| iter | int | `2000` | 每条链总迭代数 |
| warmup | int | `1000` | 每条链 warmup 迭代数 |
| seed | int | `20260407` | 随机种子 |

---

## 4. 冻结规则

### 4.1 分离规则
config 参数必须与以下内容分离：
- input data file
- Stan model code
- shell script / R script

### 4.2 版本规则
以下内容一旦变化，必须通过 config versioning 记录：
- borrowing 参数
- trimming 规则
- survival cut points
- MCMC settings

### 4.3 作用范围
本 config 控制：
- borrowing 相关分析设置
- MCMC runtime settings

本 config **不**定义：
- 原始数据清洗规则
- plotting style
- GUI 行为

---

## 5. 配置示例

```json
{
  "model_name": "borrowing_v1",
  "outcome_type": "survival",
  "a0": 0.5,
  "trim_lower": 0.01,
  "trim_upper": 0.99,
  "cut_points": [6, 12, 18, 24, 30],
  "use_ps_weight": true,
  "chains": 4,
  "iter": 2000,
  "warmup": 1000,
  "seed": 20260407
}
```

---

## 6. 当前原型对应说明

### 6.1 当前原型中的统计设置
当前原型使用：
- `a0 = 0.5`
- `trim_lower = 0.01`
- `trim_upper = 0.99`
- `cut_points = c(6, 12, 18, 24, 30)`
- `use_ps_weight = TRUE`

### 6.2 当前原型中的 MCMC 设置
当前原型使用：
- `chains = 4`
- `iter = 2000`
- `warmup = 1000`
- `seed = 20260407`

---

## 7. 未来可扩展字段
未来可考虑加入的可选字段包括：
- `adapt_delta`
- `max_treedepth`
- `init`
- `save_warmup`
- `parallel_chains`

这些字段在 v0.1 中尚未冻结。