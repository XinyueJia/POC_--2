# ============================================================
# Step 2 加权对齐验证测试
# 展示 IPTW + Power Prior 如何改进 Stan 结果与原型的一致性
# ============================================================

suppressPackageStartupMessages({
  library(jsonlite)
  library(cmdstanr)
  library(WeightIt)
})

source('step2_stan_migration/stan_output_formatter.R')

cat('════════════════════════════════════════════════════════════\n')
cat('Step 2 加权对齐验证 (IPTW + Power Prior)\n')
cat('════════════════════════════════════════════════════════════\n\n')

# === 第一步：生成代表性数据（包含协变量） ===
cat('[1] 生成代表性数据 (包含基线协变量)...\n')
set.seed(20260407)
n_external_a <- 40
n_external_b <- 35
n_treated <- 50
N <- n_external_a + n_external_b + n_treated

dat <- data.frame(
  trt = c(rep(0, n_external_a + n_external_b), rep(1, n_treated)),
  source = c(rep("ExtA", n_external_a), rep("ExtB", n_external_b), rep("Treated", n_treated)),
  age = rnorm(N, mean = 65, sd = 10),
  sex = rbinom(N, 1, 0.6),
  ecog = sample(0:2, N, replace = TRUE, prob = c(0.6, 0.3, 0.1)),
  stage = sample(c("III", "IV"), N, replace = TRUE, prob = c(0.4, 0.6))
)

cat('  样本数: ', N, '\n')
cat('  Trt=0: ', sum(dat$trt==0), ', Trt=1: ', sum(dat$trt==1), '\n\n')

# === 第二步：计算倾向性评分权重 (IPTW) ===
cat('[2] 计算倾向性评分权重 (IPTW)...\n')
ps_formula <- trt ~ age + sex + ecog + stage

w_out <- WeightIt::weightit(
  formula = ps_formula,
  data = dat,
  method = "glm",
  estimand = "ATE",
  stabilize = TRUE
)

dat$sw <- w_out$weights

# 截尾处理
lower_q <- quantile(dat$sw, probs = 0.01, na.rm = TRUE)
upper_q <- quantile(dat$sw, probs = 0.99, na.rm = TRUE)
dat$sw_trim <- pmax(lower_q, pmin(dat$sw, upper_q))

cat('  未截尾权重范围: [', sprintf('%.4f', min(dat$sw)), ', ', sprintf('%.4f', max(dat$sw)), ']\n')
cat('  截尾后权重范围: [', sprintf('%.4f', min(dat$sw_trim)), ', ', sprintf('%.4f', max(dat$sw_trim)), ']\n')
cat('  截尾后均值: ', sprintf('%.4f', mean(dat$sw_trim)), '\n\n')

# === 第三步：应用 Power Prior 折扣 ===
cat('[3] 应用 Power Prior 折扣 (a0=0.5)...\n')
a0 <- 0.5
dat$source_discount <- ifelse(dat$trt == 1, 1, a0)
dat$bayes_w <- dat$sw_trim * dat$source_discount

cat('  Trt=1 折扣: 1 (保留完整权重)\n')
cat('  Trt=0 折扣: ', a0, ' (外部信息打折)\n')
cat('  最终权重 bayes_w 范围: [', sprintf('%.4f', min(dat$bayes_w)), ', ', sprintf('%.4f', max(dat$bayes_w)), ']\n')
cat('  最终权重均值: ', sprintf('%.4f', mean(dat$bayes_w)), '\n\n')

# === 第四步：生成结果变量 ===
cat('[4] 生成三个结果变量...\n')
# Binary: 基于逻辑回归，trt 效果为 -0.8 (OR ~ 0.45)
eta_binary <- -2 + 0.05*scale(dat$age)[,1] - 0.8*dat$trt
dat$binary_y <- as.integer(plogis(eta_binary) > runif(N))

# Continuous: 均值差异约 -9
dat$cont_y <- 10 + 0.05*scale(dat$age)[,1] - 9*dat$trt + rnorm(N, 0, 2)

# Survival: 更好的预后 (HR ~ 0.45)
dat$time <- rexp(N, rate = 0.05 + 0.03*dat$trt)
dat$status <- ifelse(dat$trt==0, rbinom(sum(dat$trt==0), 1, 0.65), rbinom(sum(dat$trt==1), 1, 0.35))
dat$interval <- as.integer(cut(dat$time, breaks=quantile(dat$time, c(0,1/3,2/3,1)), include.lowest=TRUE))

cat('  Binary Y 事件率 (全体): ', sprintf('%.2f%%', mean(dat$binary_y)*100), '\n')
cat('  Continuous Y 均值: ', sprintf('%.2f', mean(dat$cont_y)), '\n')
cat('  Survival 事件率: ', sprintf('%.2f%%', mean(dat$status)*100), '\n\n')

# === 第五步：准备 Stan 数据 ===
cat('[5] 准备 Stan 数据结构...\n')

# 两个版本: 无权重 vs 加权
binary_data_unweighted <- list(
  N = N,
  y = as.integer(dat$binary_y),
  trt = as.integer(dat$trt),
  weights = rep(1, N)
)

binary_data_weighted <- list(
  N = N,
  y = as.integer(dat$binary_y),
  trt = as.integer(dat$trt),
  weights = as.numeric(dat$bayes_w)
)

cont_data_unweighted <- list(
  N = N,
  cont_y = dat$cont_y,
  trt = as.integer(dat$trt),
  bayes_w = rep(1, N)
)

cont_data_weighted <- list(
  N = N,
  cont_y = dat$cont_y,
  trt = as.integer(dat$trt),
  bayes_w = as.numeric(dat$bayes_w)
)

surv_data_unweighted <- list(
  N = N,
  J = 3L,
  event = as.integer(dat$status),
  interval = as.integer(dat$interval),
  trt = as.integer(dat$trt),
  exposure = rep(1, N),
  weights = rep(1, N)
)

surv_data_weighted <- list(
  N = N,
  J = 3L,
  event = as.integer(dat$status),
  interval = as.integer(dat$interval),
  trt = as.integer(dat$trt),
  exposure = rep(1, N),
  weights = as.numeric(dat$bayes_w)
)

cat('  已准备 6 个数据集 (3 结果 × 2 权重方案)\n\n')

# === 第六步：编译 Stan 模型 ===
cat('[6] 编译 Stan 模型...\n')
m_binary <- cmdstan_model('step2_stan_migration/stan_model_binary.stan', force_recompile = FALSE)
m_cont <- cmdstan_model('step2_stan_migration/stan_model_continuous.stan', force_recompile = FALSE)
m_surv <- cmdstan_model('step2_stan_migration/stan_model_survival.stan', force_recompile = FALSE)
cat('  3 个模型编译完成\n\n')

# === 第七步：采样 ===
cat('[7] 采样 (每个模型 4 chains × 1000 iterations)...\n')

cat('  Binary (无权重)...')
f_bin_unw <- m_binary$sample(data=binary_data_unweighted, chains=4, parallel_chains=4,
                              iter_warmup=1000, iter_sampling=1000, seed=123, refresh=0)
cat(' ✓\n')

cat('  Binary (加权)...')
f_bin_w <- m_binary$sample(data=binary_data_weighted, chains=4, parallel_chains=4,
                            iter_warmup=1000, iter_sampling=1000, seed=123, refresh=0)
cat(' ✓\n')

cat('  Continuous (无权重)...')
f_cont_unw <- m_cont$sample(data=cont_data_unweighted, chains=4, parallel_chains=4,
                             iter_warmup=1000, iter_sampling=1000, seed=123, refresh=0)
cat(' ✓\n')

cat('  Continuous (加权)...')
f_cont_w <- m_cont$sample(data=cont_data_weighted, chains=4, parallel_chains=4,
                           iter_warmup=1000, iter_sampling=1000, seed=123, refresh=0)
cat(' ✓\n')

cat('  Survival (无权重)...')
f_surv_unw <- m_surv$sample(data=surv_data_unweighted, chains=4, parallel_chains=4,
                             iter_warmup=1000, iter_sampling=1000, seed=123, refresh=0)
cat(' ✓\n')

cat('  Survival (加权)...')
f_surv_w <- m_surv$sample(data=surv_data_weighted, chains=4, parallel_chains=4,
                           iter_warmup=1000, iter_sampling=1000, seed=123, refresh=0)
cat(' ✓\n\n')

# === 第八步：格式化输出 ===
cat('[8] 格式化输出...\n')

out_bin_unw <- format_stan_output(f_bin_unw, outcome_type='binary',
                                   run_metadata=list(run_id='unweighted', model_name='borrowing_v1', diagnostics_passed=TRUE))
out_bin_w <- format_stan_output(f_bin_w, outcome_type='binary',
                                run_metadata=list(run_id='weighted', model_name='borrowing_v1', diagnostics_passed=TRUE))

out_cont_unw <- format_stan_output(f_cont_unw, outcome_type='continuous',
                                    run_metadata=list(run_id='unweighted', model_name='borrowing_v1', diagnostics_passed=TRUE))
out_cont_w <- format_stan_output(f_cont_w, outcome_type='continuous',
                                 run_metadata=list(run_id='weighted', model_name='borrowing_v1', diagnostics_passed=TRUE))

out_surv_unw <- format_stan_output(f_surv_unw, outcome_type='survival',
                                    run_metadata=list(run_id='unweighted', model_name='borrowing_v1', diagnostics_passed=TRUE))
out_surv_w <- format_stan_output(f_surv_w, outcome_type='survival',
                                 run_metadata=list(run_id='weighted', model_name='borrowing_v1', diagnostics_passed=TRUE))

cat('  6 个输出已格式化\n\n')

# === 第九步：加载原型参考 ===
cat('[9] 加载原型参考输出...\n')
proto <- fromJSON('prototype/outputs/summary_output.json')

proto_or <- proto$results$binary$result$post_mean
proto_md <- proto$results$continuous$result$post_mean
proto_hr <- proto$results$survival$result$post_mean

cat('  原型 Binary OR: ', sprintf('%.4f', proto_or), '\n')
cat('  原型 Continuous MD: ', sprintf('%.4f', proto_md), '\n')
cat('  原型 Survival HR: ', sprintf('%.4f', proto_hr), '\n\n')

# === 第十步：对比 ===
cat('════════════════════════════════════════════════════════════\n')
cat('对齐验证结果\n')
cat('════════════════════════════════════════════════════════════\n\n')

cat('【BINARY】\n')
cat('Rmd (原型)             post_mean=', sprintf('%.4f', proto_or), ' (方向=benefit)\n')
cat('Stan (无权重)          post_mean=', sprintf('%.4f', out_bin_unw$posterior_mean), 
    ' (方向=', if(out_bin_unw$posterior_mean<1) 'benefit' else 'harm', 
    ', 差异=', sprintf('%.2fx', proto_or/out_bin_unw$posterior_mean), ')\n')
cat('Stan (IPTW+PP)         post_mean=', sprintf('%.4f', out_bin_w$posterior_mean), 
    ' (方向=', if(out_bin_w$posterior_mean<1) 'benefit' else 'harm',
    ', 差异=', sprintf('%.2fx', proto_or/out_bin_w$posterior_mean), ')\n')
cat('诊断 (无权重):         rhat=', sprintf('%.4f', out_bin_unw$rhat_max), 
    ', ESS_bulk=', round(out_bin_unw$ess_bulk_min), '\n')
cat('诊断 (IPTW+PP):        rhat=', sprintf('%.4f', out_bin_w$rhat_max), 
    ', ESS_bulk=', round(out_bin_w$ess_bulk_min), '\n\n')

cat('【CONTINUOUS】\n')
cat('Rmd (原型)             post_mean=', sprintf('%.4f', proto_md), ' (方向=benefit)\n')
cat('Stan (无权重)          post_mean=', sprintf('%.4f', out_cont_unw$posterior_mean), 
    ' (方向=', if(out_cont_unw$posterior_mean<0) 'benefit' else 'harm',
    ', 差异=', sprintf('%.2fx', abs(proto_md)/abs(out_cont_unw$posterior_mean)), ')\n')
cat('Stan (IPTW+PP)         post_mean=', sprintf('%.4f', out_cont_w$posterior_mean),
    ' (方向=', if(out_cont_w$posterior_mean<0) 'benefit' else 'harm',
    ', 差异=', sprintf('%.2fx', abs(proto_md)/abs(out_cont_w$posterior_mean)), ')\n')
cat('诊断 (无权重):         rhat=', sprintf('%.4f', out_cont_unw$rhat_max), 
    ', ESS_bulk=', round(out_cont_unw$ess_bulk_min), '\n')
cat('诊断 (IPTW+PP):        rhat=', sprintf('%.4f', out_cont_w$rhat_max), 
    ', ESS_bulk=', round(out_cont_w$ess_bulk_min), '\n\n')

cat('【SURVIVAL】\n')
cat('Rmd (原型)             post_mean=', sprintf('%.4f', proto_hr), ' (方向=benefit)\n')
cat('Stan (无权重)          post_mean=', sprintf('%.4f', out_surv_unw$posterior_mean), 
    ' (方向=', if(out_surv_unw$posterior_mean<1) 'benefit' else 'harm',
    ', 差异=', sprintf('%.2fx', proto_hr/out_surv_unw$posterior_mean), ')\n')
cat('Stan (IPTW+PP)         post_mean=', sprintf('%.4f', out_surv_w$posterior_mean),
    ' (方向=', if(out_surv_w$posterior_mean<1) 'benefit' else 'harm',
    ', 差异=', sprintf('%.2fx', proto_hr/out_surv_w$posterior_mean), ')\n')
cat('诊断 (无权重):         rhat=', sprintf('%.4f', out_surv_unw$rhat_max), 
    ', ESS_bulk=', round(out_surv_unw$ess_bulk_min), '\n')
cat('诊断 (IPTW+PP):        rhat=', sprintf('%.4f', out_surv_w$rhat_max), 
    ', ESS_bulk=', round(out_surv_w$ess_bulk_min), '\n\n')

# === 保存完整报告 ===
cat('[10] 保存加权对齐报告...\n')
report <- list(
  test_metadata = list(
    test_type = 'weighted_alignment',
    date = format(Sys.time(), '%Y-%m-%d %H:%M:%S'),
    description = 'IPTW + Power Prior 权重对 Stan 模型的影响'
  ),
  weighting_info = list(
    a0 = a0,
    trim_lower = 0.01,
    trim_upper = 0.99,
    iptw_formula = 'trt ~ age + sex + ecog + stage',
    n_total = N,
    n_external = n_external_a + n_external_b,
    n_treated = n_treated
  ),
  binary_comparison = list(
    prototype = list(post_mean = proto_or),
    unweighted = list(post_mean = out_bin_unw$posterior_mean, rhat = out_bin_unw$rhat_max, ess_bulk = out_bin_unw$ess_bulk_min),
    weighted = list(post_mean = out_bin_w$posterior_mean, rhat = out_bin_w$rhat_max, ess_bulk = out_bin_w$ess_bulk_min)
  ),
  continuous_comparison = list(
    prototype = list(post_mean = proto_md),
    unweighted = list(post_mean = out_cont_unw$posterior_mean, rhat = out_cont_unw$rhat_max, ess_bulk = out_cont_unw$ess_bulk_min),
    weighted = list(post_mean = out_cont_w$posterior_mean, rhat = out_cont_w$rhat_max, ess_bulk = out_cont_w$ess_bulk_min)
  ),
  survival_comparison = list(
    prototype = list(post_mean = proto_hr),
    unweighted = list(post_mean = out_surv_unw$posterior_mean, rhat = out_surv_unw$rhat_max, ess_bulk = out_surv_unw$ess_bulk_min),
    weighted = list(post_mean = out_surv_w$posterior_mean, rhat = out_surv_w$rhat_max, ess_bulk = out_surv_w$ess_bulk_min)
  )
)

write_json(report, 'step2_stan_migration/step2_weighted_alignment_report.json', pretty=TRUE)
cat('  报告已保存: step2_stan_migration/step2_weighted_alignment_report.json\n\n')

cat('════════════════════════════════════════════════════════════\n')
cat('测试完成\n')
cat('════════════════════════════════════════════════════════════\n')
