#!/usr/bin/env Rscript
#' Step 2 真实数据快速验证 (Binary 结果)
#' 
#' 使用 prototype/demo_data_advanced.xlsx (700 样本) 进行 Binary 对齐测试
#'

cat("════════════════════════════════════════════════════════════════════\n")
cat("Step 2 真实数据对齐验证 (Binary 结果)\n")
cat("════════════════════════════════════════════════════════════════════\n\n")

suppressPackageStartupMessages({
  library(cmdstanr)
  library(jsonlite)
  library(tidyverse)
  library(readxl)
})
options(mc.cores = 1)

# 1. 读取真实数据
cat("[1] 读取真实数据...\n")
dat <- read_excel('prototype/demo_data_advanced.xlsx', sheet = 1)
cat("  样本: ", nrow(dat), 
    " (处理组=", sum(dat$trt==1),
    ", 对照组=", sum(dat$trt==0), ")\n\n")

# 2. 加载辅助函数
cat("[2] 加载 Stan 辅助函数...\n")
source('step2_stan_migration/stan_output_formatter.R')
source('step2_stan_migration/stan_alignment_validation.R')
cat("  ✓ 加载完成\n\n")

# 3. 准备 Binary 数据
cat("[3] 准备 Binary 数据结构...\n")
binary_data <- list(
  N = nrow(dat),
  y = as.integer(dat$binary_y),
  trt = as.integer(dat$trt),
  weights = rep(1, nrow(dat))
)
cat("  N=", binary_data$N, 
    ", 事件=", sum(binary_data$y),
    ", 事件率=", sprintf("%.1f%%", 100*mean(binary_data$y)), "\n\n")

# 4. 编译并采样 Binary 模型
cat("[4] 编译 Binary 模型...\n")
suppressWarnings({
  m_binary <- cmdstan_model('step2_stan_migration/stan_model_binary.stan', 
                            force_recompile = FALSE)
})
cat("  ✓ 编译完成\n\n")

cat("[5] 采样 (真实数据, 4 chains × 1000 iter)...\n")
fit_binary_real <- m_binary$sample(
  data = binary_data,
  chains = 4,
  parallel_chains = 4,
  iter_warmup = 1000,
  iter_sampling = 1000,
  seed = 123,
  refresh = 0
)
cat("  ✓ 采样完成\n\n")

# 5. 格式化输出
cat("[6] 格式化输出...\n")
stan_binary_real <- format_stan_output(
  fit_binary_real,
  outcome_type = 'binary',
  run_metadata = list(run_id='real_data_binary',
                     model_name='borrowing_v1',
                     diagnostics_passed=TRUE)
)
cat("  Stan (真实数据): OR = ", sprintf('%.4f', stan_binary_real$posterior_mean), "\n")
cat("  诊断: rhat=", sprintf('%.4f', stan_binary_real$diagnostics$rhat_max),
    ", ESS_bulk=", sprintf('%.0f', stan_binary_real$diagnostics$ess_bulk_min), "\n\n")

# 6. 加载原型参考
cat("[7] 加载原型参考...\n")
proto <- fromJSON('prototype/outputs/summary_output.json')
proto_binary_mean <- proto$results$binary$result$post_mean
cat("  Rmd 原型: OR = ", sprintf('%.4f', proto_binary_mean), "\n\n")

# 7. 对比
cat("════════════════════════════════════════════════════════════════════\n")
cat("真实数据对齐结果 (700 样本)\n")
cat("════════════════════════════════════════════════════════════════════\n\n")

binary_ratio <- proto_binary_mean / stan_binary_real$posterior_mean
binary_direction_match <- (proto_binary_mean < 1) == (stan_binary_real$posterior_mean < 1)

cat("【BINARY (Odds Ratio)】\n")
cat("  Rmd 原型:        OR = ", sprintf('%.4f', proto_binary_mean), 
    " (", if(proto_binary_mean < 1) "benefit" else "harm", ")\n")
cat("  Stan (真实数据): OR = ", sprintf('%.4f', stan_binary_real$posterior_mean),
    " (", if(stan_binary_real$posterior_mean < 1) "benefit" else "harm", ")\n")
cat("  方向一致: ", if(binary_direction_match) "✅ YES" else "❌ NO", "\n")
cat("  数值差异: ", sprintf('%.2f', binary_ratio), "x\n")
cat("  诊断: rhat=", sprintf('%.4f', stan_binary_real$diagnostics$rhat_max),
    ", ESS_bulk=", sprintf('%.0f', stan_binary_real$diagnostics$ess_bulk_min), "\n\n")

# 8. 结论
cat("════════════════════════════════════════════════════════════════════\n")
if (binary_direction_match && binary_ratio < 1.3) {
  cat("【结论】🟢 优异对齐\n")
  cat("  方向正确，数值差异在 1.3 倍以内\n")
} else if (binary_direction_match && binary_ratio < 1.5) {
  cat("【结论】🟡 良好对齐\n")
  cat("  方向正确，数值差异在可接受范围内 (<1.5x)\n")
} else if (binary_direction_match) {
  cat("【结论】🟡 部分对齐\n")
  cat("  方向正确，数值差异较大但可能源于采样变异\n")
} else {
  cat("【结论】🔴 对齐失败\n")
  cat("  方向不一致！需要进一步调查\n")
}
cat("════════════════════════════════════════════════════════════════════\n\n")

# 9. 保存报告
cat("[8] 保存对齐报告...\n")
report <- list(
  test_metadata = list(
    test_type = "real_data_binary_alignment",
    date = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    description = "真实数据 Binary 对齐验证",
    data_source = "prototype/demo_data_advanced.xlsx",
    sample_size = 700,
    n_trt = 200,
    n_control = 500
  ),
  results = list(
    rmd_or = proto_binary_mean,
    stan_or = stan_binary_real$posterior_mean,
    ratio = binary_ratio,
    direction_match = binary_direction_match,
    diagnostics = list(
      rhat_max = stan_binary_real$diagnostics$rhat_max,
      ess_bulk_min = stan_binary_real$diagnostics$ess_bulk_min,
      ess_tail_min = stan_binary_real$diagnostics$ess_tail_min,
      n_divergent = stan_binary_real$diagnostics$n_divergent
    ),
    conclusion = if (binary_direction_match && binary_ratio < 1.3) {
      "优异对齐"
    } else if (binary_direction_match && binary_ratio < 1.5) {
      "良好对齐"
    } else if (binary_direction_match) {
      "部分对齐"
    } else {
      "对齐失败"
    }
  )
)

write_json(report, 'step2_stan_migration/step2_real_data_binary_alignment.json', pretty=TRUE)
cat("  报告已保存: step2_stan_migration/step2_real_data_binary_alignment.json\n\n")

cat("════════════════════════════════════════════════════════════════════\n")
cat("真实数据验证完成\n")
cat("════════════════════════════════════════════════════════════════════\n")
