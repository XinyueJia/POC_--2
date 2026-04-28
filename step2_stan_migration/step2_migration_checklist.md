# Step 2 迁移验证清单

## 1. 接口冻结

- [x] binary / continuous / survival 三类结局的输入字段已明确
- [x] `trt`、`source`、`weight`、`offset` 等关键字段的语义已明确
- [x] 输出字段与 `output_contract.md` 一致

## 2. 数据转换

- [x] `stan_data_preparation.R` 可将原型输出转换为 Stan data 结构
- [x] 二分类、连续、生存三类数据均可单独构造
- [x] 缺失值、编码、分组变量处理规则已明确

## 3. 模型实现

- [x] `stan_model_binary.stan` 完成
- [x] `stan_model_continuous.stan` 完成
- [x] `stan_model_survival.stan` 完成
- [x] 模型参数命名与 Step 1 规范一致

## 4. 执行与输出

- [x] `stan_execution.R` 可读取 `config/config.json`
- [x] `stan_output_formatter.R` 可生成 summary 输出
- [ ] 关键诊断项可被保留并回写到输出结果

## 5. 对齐验证

- [ ] Stan 与 Rmd 的主要效应方向一致
- [ ] Stan 与 Rmd 的 summary 指标一致或在可解释误差内
- [ ] 诊断阈值与原型一致
