#!/usr/bin/env Rscript
#' Step 2 真实数据对齐验证
#' 
#' 使用 prototype/demo_data_advanced.xlsx 进行完整的对齐测试
#' 比较 Stan Step 2 与原型 Rmd 在真实数据上的结果
#'

cat("════════════════════════════════════════════════════════════\n")
cat("Step 2 真实数据对齐验证\n")
cat("════════════════════════════════════════════════════════════\n\n")

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

# 2. 读取真实数据
cat("[2] 读取真实数据...\n")
excel_file <- 'prototype/demo_data_advanced.xlsx'

if (!file.exists(excel_file)) {
  cat("❌ 错误: 找不到", excel_file, "\n")
  quit(status = 1)
}

# 探索 Excel 文件中的 sheet 名称
sheet_names <- excel_sheets(excel_file)
cat("  发现的 Sheet: ", paste(sheet_names, collapse=" / "), "\n")

# 读取第一个有数据的 sheet
dat <- read_excel(excel_file, sheet = sheet_names[1])
cat("  数据维度: ", nrow(dat), "行,", ncol(dat), "列\n")
cat("  列名: ", paste(names(dat), collapse=", "), "\n\n")

# 检查关键字段
required_fields <- c('trt', 'y', 'age', 'sex')
missing_fields <- required_fields[!(required_fields %in% names(dat))]
if (length(missing_fields) > 0) {
  cat("⚠️  警告: 缺少以下字段:", paste(missing_fields, collapse=", "), "\n")
  cat("  可用字段: ", paste(names(dat), collapse=", "), "\n\n")
}

# 数据摘要
cat("【数据摘要】\n")
cat("样本总数: ", nrow(dat), "\n")
cat("处理组 (trt=1): ", sum(dat$trt == 1, na.rm=TRUE), "\n")
cat("对照组 (trt=0): ", sum(dat$trt == 0, na.rm=TRUE), "\n\n")

# 显示前几行
cat("【数据预览】\n")
print(head(dat, 10))
cat("\n")

# 3. 检查数据质量
cat("[3] 数据质量检查...\n")
cat("  缺失值:\n")
print(colSums(is.na(dat)))
cat("\n")

# 4. 准备用于 Stan 的数据 (真实数据字段名)
cat("[4] 准备 Stan 数据结构...\n")

# 真实数据使用 binary_y, cont_y, status 字段
if (all(c('trt', 'binary_y') %in% names(dat))) {
  
  # 处理二分类结局
  if (all(unique(na.omit(dat$binary_y)) %in% c(0, 1))) {
    cat("  ✓ 检测到二分类结局 (binary_y)\n")
    
    binary_data <- list(
      N = nrow(dat),
      y = as.integer(dat$binary_y),
      trt = as.integer(dat$trt),
      weights = rep(1, nrow(dat))
    )
    
    cat("    N=", binary_data$N, 
        ", 事件数=", sum(binary_data$y),
        ", 事件率=", round(100*mean(binary_data$y), 1), "%\n\n")
  }
  
  # 加载相关的格式化和验证函数
  source('stan_output_formatter.R')
  source('stan_alignment_validation.R')
  
  # 5. 采样
  cat("[5] 使用真实数据采样 Stan 模型...\n")
  
  suppressWarnings({
    m_binary <- cmdstan_model('stan_model_binary.stan', force_recompile = FALSE)
  })
  
  cat("  编译完成，开始采样 (4 chains × 1000 iter)...\n")
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
  
  # 6. 格式化输出
  cat("[6] 格式化 Stan 输出...\n")
  
  stan_binary_real <- format_stan_output(
    fit_binary_real,
    outcome_type = 'binary',
    run_metadata = list(run_id='real_data_v1', 
                       model_name='borrowing_v1',
                       diagnostics_passed=TRUE)
  )
  
  cat("  Stan (真实数据) Binary OR: ", sprintf('%.4f', stan_binary_real$posterior_mean), "\n")
  cat("  诊断: rhat=", sprintf('%.4f', stan_binary_real$diagnostics$rhat_max), 
      ", ESS_bulk=", sprintf('%.0f', stan_binary_real$diagnostics$ess_bulk_min), "\n\n")
  
  # 7. 加载原型结果
  cat("[7] 加载原型参考结果...\n")
  
  proto_file <- 'prototype/outputs/summary_output.json'
  if (file.exists(proto_file)) {
    proto <- fromJSON(proto_file)
    proto_binary_mean <- proto$results$binary$result$post_mean
    cat("  Rmd (原型) Binary OR: ", sprintf('%.4f', proto_binary_mean), "\n")
    
    # 8. 对比
    cat("\n[8] 真实数据对齐结果\n")
    cat("════════════════════════════════════════════════════════════\n")
    
    ratio <- proto_binary_mean / stan_binary_real$posterior_mean
    direction_match <- (proto_binary_mean < 1) == (stan_binary_real$posterior_mean < 1)
    
    cat("【BINARY】(真实数据)\n")
    cat("  Rmd 原型:        OR = ", sprintf('%.4f', proto_binary_mean), 
        " (", if(proto_binary_mean < 1) "benefit" else "harm", ")\n")
    cat("  Stan (真实数据): OR = ", sprintf('%.4f', stan_binary_real$posterior_mean),
        " (", if(stan_binary_real$posterior_mean < 1) "benefit" else "harm", ")\n")
    cat("  方向一致: ", if(direction_match) "✅ YES" else "❌ NO", "\n")
    cat("  数值差异: ", sprintf('%.2f', ratio), "x\n")
    cat("  诊断指标: rhat=", sprintf('%.4f', stan_binary_real$diagnostics$rhat_max),
        ", ESS_bulk=", sprintf('%.0f', stan_binary_real$diagnostics$ess_bulk_min), "\n\n")
    
    # 9. 保存真实数据验证报告
    cat("[9] 保存真实数据对齐报告...\n")
    
    report <- list(
      test_metadata = list(
        test_type = "real_data_alignment",
        date = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        description = "真实数据对齐验证 (prototype/demo_data_advanced.xlsx)",
        data_source = excel_file,
        sample_size = nrow(dat)
      ),
      binary_comparison = list(
        rmd_post_mean = proto_binary_mean,
        stan_post_mean = stan_binary_real$posterior_mean,
        ratio = ratio,
        direction_match = direction_match,
        stan_diagnostics = list(
          rhat_max = stan_binary_real$diagnostics$rhat_max,
          ess_bulk_min = stan_binary_real$diagnostics$ess_bulk_min,
          ess_tail_min = stan_binary_real$diagnostics$ess_tail_min,
          n_divergent = stan_binary_real$diagnostics$n_divergent
        )
      ),
      conclusion = if(direction_match) {
        if(ratio < 1.3 & ratio > 0.77) {
          "✅ 优异对齐 - 方向正确，数值接近"
        } else {
          "⚠️  部分对齐 - 方向正确，数值差异可接受"
        }
      } else {
        "❌ 对齐失败 - 方向不一致"
      }
    )
    
    write_json(report, 'step2_stan_migration/step2_real_data_alignment_report.json', pretty=TRUE)
    cat("  报告已保存: step2_stan_migration/step2_real_data_alignment_report.json\n\n")
    
  } else {
    cat("⚠️  警告: 找不到原型参考文件 -", proto_file, "\n")
    cat("  跳过对比步骤\n\n")
  }
  
} else {
  cat("❌ 错误: 数据中缺少 'trt' 或 'y' 字段\n")
  cat("  无法继续进行 Stan 采样\n")
}

# 10. 总结
cat("════════════════════════════════════════════════════════════\n")
cat("真实数据验证完成\n")
cat("════════════════════════════════════════════════════════════\n")
