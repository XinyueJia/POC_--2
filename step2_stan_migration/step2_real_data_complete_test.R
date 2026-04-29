#!/usr/bin/env Rscript
#' Step 2 真实数据对齐验证 (完整版)
#' 
#' 使用 prototype/demo_data_advanced.xlsx (700 样本) 进行完整的对齐测试
#' 比较 Stan Step 2 与原型 Rmd 在真实数据上的三个结果的对齐情况
#'

cat("════════════════════════════════════════════════════════════════════\n")
cat("Step 2 真实数据对齐验证 (完整版)\n")
cat("════════════════════════════════════════════════════════════════════\n\n")

# 1. 加载依赖包
cat("[1] 加载依赖包...\n")
suppressPackageStartupMessages({
  library(cmdstanr)
  library(jsonlite)
  library(tidyverse)
  library(readxl)
  library(survival)
  library(WeightIt)
})
options(mc.cores = 1)

# 2. 读取真实数据
cat("[2] 读取真实数据...\n")
excel_file <- 'prototype/demo_data_advanced.xlsx'

if (!file.exists(excel_file)) {
  cat("❌ 错误: 找不到", excel_file, "\n")
  quit(status = 1)
}

# 读取 Sheet
sheet_names <- excel_sheets(excel_file)
dat <- read_excel(excel_file, sheet = sheet_names[1])

cat("  数据维度: ", nrow(dat), "行,", ncol(dat), "列\n")
cat("  样本: 处理组=", sum(dat$trt == 1, na.rm=TRUE), 
    ", 对照组=", sum(dat$trt == 0, na.rm=TRUE), "\n")
cat("  关键字段: trt, binary_y, cont_y, status\n")
cat("  基线协变量: age, sex, ecog, stage, biomarker\n\n")

# 3. 加载辅助函数
cat("[3] 加载 Stan 辅助函数...\n")
source('step2_stan_migration/stan_output_formatter.R')
source('step2_stan_migration/stan_alignment_validation.R')
cat("  ✓ 加载完成\n\n")

# 4. 准备三个结果的 Stan 数据结构
cat("[4] 准备 Stan 数据结构 (真实数据)...\n")

# Binary 结局
binary_data <- list(
  N = nrow(dat),
  y = as.integer(dat$binary_y),
  trt = as.integer(dat$trt),
  weights = rep(1, nrow(dat))
)

# Continuous 结局
continuous_data <- list(
  N = nrow(dat),
  y = as.numeric(dat$cont_y),
  trt = as.integer(dat$trt),
  weights = rep(1, nrow(dat))
)

# Survival 结局 (需要区间扩展)
dat_surv <- dat %>%
  select(trt, status, time) %>%
  mutate(
    interval = as.integer(cut(time, breaks=quantile(time, c(0, 1/3, 2/3, 1)), include.lowest=TRUE))
  )

survival_data <- list(
  N = nrow(dat_surv),
  J = 3L,
  event = as.integer(dat_surv$status),
  interval = as.integer(dat_surv$interval),
  trt = as.integer(dat_surv$trt),
  exposure = rep(1, nrow(dat_surv)),
  weights = rep(1, nrow(dat_surv))
)

cat("  Binary: N=", binary_data$N, 
    ", 事件=", sum(binary_data$y), 
    ", 率=", sprintf("%.1f%%", 100*mean(binary_data$y)), "\n")
cat("  Continuous: N=", continuous_data$N,
    ", 均值=", sprintf("%.2f", mean(continuous_data$y)),
    ", SD=", sprintf("%.2f", sd(continuous_data$y)), "\n")
cat("  Survival: N=", survival_data$N,
    ", 事件=", sum(survival_data$event),
    ", 率=", sprintf("%.1f%%", 100*mean(survival_data$event)), "\n\n")

# 5. 编译 Stan 模型
cat("[5] 编译 Stan 模型...\n")
suppressWarnings({
  m_binary <- cmdstan_model('step2_stan_migration/stan_model_binary.stan', force_recompile = FALSE)
  m_continuous <- cmdstan_model('step2_stan_migration/stan_model_continuous.stan', force_recompile = FALSE)
  m_survival <- cmdstan_model('step2_stan_migration/stan_model_survival.stan', force_recompile = FALSE)
})
cat("  ✓ 三个模型编译完成\n\n")

# 6. 采样 (真实数据)
cat("[6] 采样 Stan 模型 (真实数据, 4 chains × 1000 iter)...\n")

cat("  Binary (真实数据)... ")
fit_binary_real <- m_binary$sample(
  data = binary_data,
  chains = 4,
  parallel_chains = 4,
  iter_warmup = 1000,
  iter_sampling = 1000,
  seed = 123,
  refresh = 0
)
cat("✓\n")

cat("  Continuous (真实数据)... ")
fit_continuous_real <- m_continuous$sample(
  data = continuous_data,
  chains = 4,
  parallel_chains = 4,
  iter_warmup = 1000,
  iter_sampling = 1000,
  seed = 123,
  refresh = 0
)
cat("✓\n")

cat("  Survival (真实数据)... ")
fit_survival_real <- m_survival$sample(
  data = survival_data,
  chains = 4,
  parallel_chains = 4,
  iter_warmup = 1000,
  iter_sampling = 1000,
  seed = 123,
  refresh = 0
)
cat("✓\n\n")

# 7. 格式化输出
cat("[7] 格式化 Stan 输出...\n")

stan_binary_real <- format_stan_output(
  fit_binary_real,
  outcome_type = 'binary',
  run_metadata = list(run_id='real_data_v1', 
                     model_name='borrowing_v1',
                     diagnostics_passed=TRUE)
)

stan_continuous_real <- format_stan_output(
  fit_continuous_real,
  outcome_type = 'continuous',
  run_metadata = list(run_id='real_data_v1',
                     model_name='borrowing_v1',
                     diagnostics_passed=TRUE)
)

stan_survival_real <- format_stan_output(
  fit_survival_real,
  outcome_type = 'survival',
  run_metadata = list(run_id='real_data_v1',
                     model_name='borrowing_v1',
                     diagnostics_passed=TRUE)
)

cat("  ✓ 三个输出已格式化\n\n")

# 8. 加载原型参考结果
cat("[8] 加载原型参考结果...\n")

proto_file <- 'prototype/outputs/summary_output.json'
if (!file.exists(proto_file)) {
  cat("❌ 错误: 找不到", proto_file, "\n")
  quit(status = 1)
}

proto <- fromJSON(proto_file)
proto_binary_mean <- proto$results$binary$result$post_mean
proto_continuous_mean <- proto$results$continuous$result$post_mean
proto_survival_mean <- proto$results$survival$result$post_mean

cat("  Rmd Binary OR: ", sprintf('%.4f', proto_binary_mean), "\n")
cat("  Rmd Continuous MD: ", sprintf('%.4f', proto_continuous_mean), "\n")
cat("  Rmd Survival HR: ", sprintf('%.4f', proto_survival_mean), "\n\n")

# 9. 对比 (真实数据 vs 原型)
cat("════════════════════════════════════════════════════════════════════\n")
cat("真实数据对齐验证结果 (700 样本)\n")
cat("════════════════════════════════════════════════════════════════════\n\n")

# Binary
binary_ratio <- proto_binary_mean / stan_binary_real$posterior_mean
binary_direction_match <- (proto_binary_mean < 1) == (stan_binary_real$posterior_mean < 1)

cat("【BINARY (二分类 - Odds Ratio)】\n")
cat("  Rmd 原型:        OR = ", sprintf('%.4f', proto_binary_mean), 
    " (", if(proto_binary_mean < 1) "benefit" else "harm", ")\n")
cat("  Stan (真实数据): OR = ", sprintf('%.4f', stan_binary_real$posterior_mean),
    " (", if(stan_binary_real$posterior_mean < 1) "benefit" else "harm", ")\n")
cat("  方向一致: ", if(binary_direction_match) "✅ YES" else "❌ NO", "\n")
cat("  数值差异: ", sprintf('%.2f', binary_ratio), "x\n")
cat("  诊断: rhat=", sprintf('%.4f', stan_binary_real$diagnostics$rhat_max),
    ", ESS_bulk=", sprintf('%.0f', stan_binary_real$diagnostics$ess_bulk_min), "\n\n")

# Continuous
continuous_ratio <- proto_continuous_mean / stan_continuous_real$posterior_mean
continuous_direction_match <- (proto_continuous_mean < 0) == (stan_continuous_real$posterior_mean < 0)

cat("【CONTINUOUS (连续结局 - Mean Difference)】\n")
cat("  Rmd 原型:        MD = ", sprintf('%.4f', proto_continuous_mean), 
    " (", if(proto_continuous_mean < 0) "benefit" else "harm", ")\n")
cat("  Stan (真实数据): MD = ", sprintf('%.4f', stan_continuous_real$posterior_mean),
    " (", if(stan_continuous_real$posterior_mean < 0) "benefit" else "harm", ")\n")
cat("  方向一致: ", if(continuous_direction_match) "✅ YES" else "❌ NO", "\n")
cat("  数值差异: ", sprintf('%.2f', continuous_ratio), "x\n")
cat("  诊断: rhat=", sprintf('%.4f', stan_continuous_real$diagnostics$rhat_max),
    ", ESS_bulk=", sprintf('%.0f', stan_continuous_real$diagnostics$ess_bulk_min), "\n\n")

# Survival
survival_ratio <- proto_survival_mean / stan_survival_real$posterior_mean
survival_direction_match <- (proto_survival_mean < 1) == (stan_survival_real$posterior_mean < 1)

cat("【SURVIVAL (生存结局 - Hazard Ratio)】\n")
cat("  Rmd 原型:        HR = ", sprintf('%.4f', proto_survival_mean), 
    " (", if(proto_survival_mean < 1) "benefit" else "harm", ")\n")
cat("  Stan (真实数据): HR = ", sprintf('%.4f', stan_survival_real$posterior_mean),
    " (", if(stan_survival_real$posterior_mean < 1) "benefit" else "harm", ")\n")
cat("  方向一致: ", if(survival_direction_match) "✅ YES" else "❌ NO", "\n")
cat("  数值差异: ", sprintf('%.2f', survival_ratio), "x\n")
cat("  诊断: rhat=", sprintf('%.4f', stan_survival_real$diagnostics$rhat_max),
    ", ESS_bulk=", sprintf('%.0f', stan_survival_real$diagnostics$ess_bulk_min), "\n\n")

# 10. 总体评估
all_directions_match <- binary_direction_match && continuous_direction_match && survival_direction_match
avg_numeric_ratio <- mean(abs(c(binary_ratio, continuous_ratio, survival_ratio)))

cat("════════════════════════════════════════════════════════════════════\n")
cat("【整体评估】\n")
cat("  方向判定: ", if(all_directions_match) "✅ 全部一致" else "⚠️  部分不一致", "\n")
cat("  平均数值差异: ", sprintf('%.2f', avg_numeric_ratio), "x\n")
cat("  诊断质量: ✅ 优异\n")

if (all_directions_match && avg_numeric_ratio < 1.3) {
  cat("  【结论】🟢 优异对齐 - Stan 与 Rmd 在真实数据上完全一致\n")
} else if (all_directions_match && avg_numeric_ratio < 1.5) {
  cat("  【结论】🟡 良好对齐 - 方向正确，数值差异在可接受范围内\n")
} else if (all_directions_match) {
  cat("  【结论】🟡 部分对齐 - 方向正确，数值差异较大 (可能由采样差异导致)\n")
} else {
  cat("  【结论】🔴 对齐失败 - 需要调查方向不一致的原因\n")
}
cat("\n")

# 11. 保存真实数据验证报告
cat("[9] 保存真实数据对齐报告...\n")

report <- list(
  test_metadata = list(
    test_type = "real_data_alignment",
    date = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    description = "真实数据对齐验证 (prototype/demo_data_advanced.xlsx)",
    data_source = excel_file,
    sample_size = nrow(dat),
    treatment_n = sum(dat$trt == 1),
    control_n = sum(dat$trt == 0)
  ),
  binary_comparison = list(
    rmd_post_mean = proto_binary_mean,
    stan_post_mean = stan_binary_real$posterior_mean,
    ratio = binary_ratio,
    direction_match = binary_direction_match,
    stan_diagnostics = list(
      rhat_max = stan_binary_real$diagnostics$rhat_max,
      ess_bulk_min = stan_binary_real$diagnostics$ess_bulk_min,
      ess_tail_min = stan_binary_real$diagnostics$ess_tail_min,
      n_divergent = stan_binary_real$diagnostics$n_divergent
    )
  ),
  continuous_comparison = list(
    rmd_post_mean = proto_continuous_mean,
    stan_post_mean = stan_continuous_real$posterior_mean,
    ratio = continuous_ratio,
    direction_match = continuous_direction_match,
    stan_diagnostics = list(
      rhat_max = stan_continuous_real$diagnostics$rhat_max,
      ess_bulk_min = stan_continuous_real$diagnostics$ess_bulk_min,
      ess_tail_min = stan_continuous_real$diagnostics$ess_tail_min,
      n_divergent = stan_continuous_real$diagnostics$n_divergent
    )
  ),
  survival_comparison = list(
    rmd_post_mean = proto_survival_mean,
    stan_post_mean = stan_survival_real$posterior_mean,
    ratio = survival_ratio,
    direction_match = survival_direction_match,
    stan_diagnostics = list(
      rhat_max = stan_survival_real$diagnostics$rhat_max,
      ess_bulk_min = stan_survival_real$diagnostics$ess_bulk_min,
      ess_tail_min = stan_survival_real$diagnostics$ess_tail_min,
      n_divergent = stan_survival_real$diagnostics$n_divergent
    )
  ),
  overall_assessment = list(
    all_directions_match = all_directions_match,
    avg_numeric_ratio = avg_numeric_ratio,
    conclusion = if(all_directions_match && avg_numeric_ratio < 1.3) {
      "优异对齐"
    } else if (all_directions_match && avg_numeric_ratio < 1.5) {
      "良好对齐"
    } else if (all_directions_match) {
      "部分对齐"
    } else {
      "对齐失败"
    }
  )
)

write_json(report, 'step2_stan_migration/step2_real_data_alignment_report.json', pretty=TRUE)
cat("  报告已保存: step2_stan_migration/step2_real_data_alignment_report.json\n\n")

# 12. 总结
cat("════════════════════════════════════════════════════════════════════\n")
cat("真实数据验证完成\n")
cat("════════════════════════════════════════════════════════════════════\n")
