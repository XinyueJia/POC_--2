`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

prototype_ps_formula <- trt ~ age + sex + ecog + stage + biomarker + prior_tx + albumin

trim_iptw_weights <- function(w, trim_lower = 0.01, trim_upper = 0.99) {
  trim_q <- as.numeric(stats::quantile(w, probs = c(trim_lower, trim_upper), na.rm = TRUE))
  pmin(pmax(w, trim_q[1]), trim_q[2])
}

read_prototype_demo_data <- function(data_path) {
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    stop("Package 'openxlsx' is required to read prototype/demo_data_advanced.xlsx.", call. = FALSE)
  }

  dat <- openxlsx::read.xlsx(data_path)
  dat$sex <- as.integer(ifelse(dat$sex == "Female", 0, ifelse(dat$sex == "Male", 1, dat$sex)))
  dat$ecog <- as.integer(dat$ecog)
  dat$stage <- as.character(dat$stage)
  dat$biomarker <- as.integer(ifelse(dat$biomarker == "Negative", 0, ifelse(dat$biomarker == "Positive", 1, dat$biomarker)))
  dat$prior_tx <- as.integer(ifelse(dat$prior_tx == "No", 0, ifelse(dat$prior_tx == "Yes", 1, dat$prior_tx)))
  dat$trt <- as.integer(dat$trt)
  dat$source <- factor(dat$source, levels = c("External_A", "External_B", "Hainan_Treated"))

  if ("status" %in% names(dat)) {
    dat$status <- as.integer(dat$status)
  }
  if ("binary_y" %in% names(dat)) {
    dat$binary_y <- as.integer(dat$binary_y)
  }

  dat
}

simulate_prototype_demo_data <- function(seed) {
  set.seed(seed)

  gen_covariates <- function(n, source_name) {
    if (source_name == "Hainan_Treated") {
      age <- round(stats::rnorm(n, 55, 7), 1)
      sex <- stats::rbinom(n, 1, 0.60)
      ecog <- sample(0:2, n, replace = TRUE, prob = c(0.50, 0.38, 0.12))
      stage <- sample(c("III", "IV"), n, replace = TRUE, prob = c(0.55, 0.45))
      biomarker <- stats::rbinom(n, 1, 0.42)
      prior_tx <- stats::rbinom(n, 1, 0.28)
      albumin <- round(stats::rnorm(n, 41.5, 4.2), 1)
    } else if (source_name == "External_A") {
      age <- round(stats::rnorm(n, 60, 8), 1)
      sex <- stats::rbinom(n, 1, 0.56)
      ecog <- sample(0:2, n, replace = TRUE, prob = c(0.35, 0.45, 0.20))
      stage <- sample(c("III", "IV"), n, replace = TRUE, prob = c(0.42, 0.58))
      biomarker <- stats::rbinom(n, 1, 0.30)
      prior_tx <- stats::rbinom(n, 1, 0.40)
      albumin <- round(stats::rnorm(n, 39.0, 4.5), 1)
    } else if (source_name == "External_B") {
      age <- round(stats::rnorm(n, 58, 9), 1)
      sex <- stats::rbinom(n, 1, 0.68)
      ecog <- sample(0:2, n, replace = TRUE, prob = c(0.28, 0.49, 0.23))
      stage <- sample(c("III", "IV"), n, replace = TRUE, prob = c(0.38, 0.62))
      biomarker <- stats::rbinom(n, 1, 0.24)
      prior_tx <- stats::rbinom(n, 1, 0.52)
      albumin <- round(stats::rnorm(n, 37.8, 4.8), 1)
    } else {
      stop("Unknown source_name: ", source_name, call. = FALSE)
    }

    data.frame(age, sex, ecog, stage, biomarker, prior_tx, albumin)
  }

  d1 <- gen_covariates(200, "Hainan_Treated")
  d2 <- gen_covariates(260, "External_A")
  d3 <- gen_covariates(240, "External_B")
  d1$source <- "Hainan_Treated"
  d2$source <- "External_A"
  d3$source <- "External_B"
  d1$trt <- 1L
  d2$trt <- 0L
  d3$trt <- 0L

  dat <- rbind(d1, d2, d3)
  dat$id <- seq_len(nrow(dat))
  stage_iv <- ifelse(dat$stage == "IV", 1, 0)

  lp_common <- 0.025 * (dat$age - 58) +
    0.18 * dat$sex +
    0.40 * dat$ecog +
    0.55 * stage_iv -
    0.35 * dat$biomarker +
    0.22 * dat$prior_tx -
    0.04 * (dat$albumin - 40) -
    0.60 * dat$trt +
    ifelse(dat$source == "External_A", 0.08, 0) +
    ifelse(dat$source == "External_B", 0.20, 0)

  shape <- 1.35
  lambda <- 0.045
  true_time <- (-log(stats::runif(nrow(dat))) / (lambda * exp(lp_common)))^(1 / shape)
  censor_time <- pmin(stats::rexp(nrow(dat), rate = 0.018), rep(36, nrow(dat)))
  dat$time <- pmin(true_time, censor_time)
  dat$status <- as.integer(true_time <= censor_time)

  lp_binary <- -0.80 +
    0.020 * (dat$age - 58) +
    0.15 * dat$sex +
    0.35 * dat$ecog +
    0.45 * stage_iv -
    0.30 * dat$biomarker +
    0.18 * dat$prior_tx -
    0.03 * (dat$albumin - 40) -
    0.55 * dat$trt +
    ifelse(dat$source == "External_A", 0.08, 0) +
    ifelse(dat$source == "External_B", 0.18, 0)
  dat$binary_y <- stats::rbinom(nrow(dat), size = 1, prob = stats::plogis(lp_binary))

  mu_cont <- 55 +
    0.35 * (dat$age - 58) +
    1.50 * dat$sex +
    3.20 * dat$ecog +
    4.50 * stage_iv -
    2.80 * dat$biomarker +
    1.80 * dat$prior_tx -
    0.70 * (dat$albumin - 40) -
    5.50 * dat$trt +
    ifelse(dat$source == "External_A", 1.50, 0) +
    ifelse(dat$source == "External_B", 3.00, 0)
  dat$cont_y <- round(stats::rnorm(nrow(dat), mean = mu_cont, sd = 6), 2)
  dat$source <- factor(dat$source, levels = c("External_A", "External_B", "Hainan_Treated"))

  dat
}

validate_prototype_aligned_data <- function(data) {
  required <- c("trt", "binary_y", "cont_y", "time", "status", "source", "age", "sex", "ecog", "stage", "biomarker", "prior_tx", "albumin")
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop("Prototype-aligned data is missing required column(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }

  checks <- list(
    trt = all(data$trt %in% c(0, 1), na.rm = TRUE),
    sex = all(data$sex %in% c(0, 1), na.rm = TRUE),
    ecog = all(data$ecog %in% c(0, 1, 2), na.rm = TRUE),
    stage = all(data$stage %in% c("III", "IV"), na.rm = TRUE),
    biomarker = all(data$biomarker %in% c(0, 1), na.rm = TRUE),
    prior_tx = all(data$prior_tx %in% c(0, 1), na.rm = TRUE),
    source = all(as.character(data$source) %in% c("Hainan_Treated", "External_A", "External_B"), na.rm = TRUE)
  )
  failed <- names(checks)[!unlist(checks)]
  if (length(failed) > 0) {
    stop("Prototype-aligned encoding validation failed for: ", paste(failed, collapse = ", "), call. = FALSE)
  }

  invisible(data)
}

compute_stabilized_iptw <- function(data) {
  if (requireNamespace("WeightIt", quietly = TRUE)) {
    w_out <- WeightIt::weightit(
      formula = prototype_ps_formula,
      data = data,
      method = "glm",
      estimand = "ATE",
      stabilize = TRUE
    )
    return(as.numeric(w_out$weights))
  }

  ps_fit <- stats::glm(prototype_ps_formula, data = data, family = stats::binomial())
  ps <- pmin(pmax(stats::predict(ps_fit, type = "response"), 1e-6), 1 - 1e-6)
  p_trt <- mean(data$trt == 1)
  ifelse(data$trt == 1, p_trt / ps, (1 - p_trt) / (1 - ps))
}

add_prototype_weights <- function(data, analysis_spec) {
  data <- as.data.frame(data)
  if (isTRUE(analysis_spec$weighting$use_ps_weight)) {
    data$iptw <- compute_stabilized_iptw(data)
    data$iptw_trim <- trim_iptw_weights(
      data$iptw,
      trim_lower = analysis_spec$weighting$trim_lower,
      trim_upper = analysis_spec$weighting$trim_upper
    )
  } else {
    data$iptw <- 1
    data$iptw_trim <- 1
  }

  data$source_discount <- ifelse(data$trt == 1, 1, analysis_spec$borrowing$a0)
  data$bayes_w <- data$iptw_trim * data$source_discount
  data
}

find_prototype_data_path <- function() {
  candidates <- c(
    file.path("prototype", "demo_data_advanced.xlsx"),
    "demo_data_advanced.xlsx"
  )
  existing <- candidates[file.exists(candidates)]
  if (length(existing) == 0) NULL else existing[[1]]
}

export_prototype_aligned_data <- function(analysis_spec, output_path = file.path(analysis_spec$paths$data_dir, "preprocessed_demo.rds")) {
  data_path <- find_prototype_data_path()
  if (!is.null(data_path)) {
    dat <- read_prototype_demo_data(data_path)
    data_source <- data_path
  } else {
    dat <- simulate_prototype_demo_data(seed = analysis_spec$mcmc$seed)
    data_source <- "prototype_simulation_logic"
  }

  dat <- validate_prototype_aligned_data(dat)
  dat <- add_prototype_weights(dat, analysis_spec)

  keep_columns <- c(
    "id", "source", "trt", "age", "sex", "ecog", "stage", "biomarker", "prior_tx", "albumin",
    "time", "status", "binary_y", "cont_y", "iptw", "iptw_trim", "source_discount", "bayes_w"
  )
  dat <- dat[, intersect(keep_columns, names(dat)), drop = FALSE]

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(dat, output_path)

  invisible(list(
    path = output_path,
    data_source = data_source,
    n_rows = nrow(dat),
    columns = names(dat)
  ))
}

run_export_prototype_aligned_data <- function() {
  source("spec/analysis_spec.R")
  result <- export_prototype_aligned_data(analysis_spec)
  message("Generated prototype-aligned preprocessed data: ", result$path)
  message("Rows: ", result$n_rows)
  message("Source: ", result$data_source)
  invisible(result)
}

if (any(grepl("R/export_prototype_aligned_data.R$", commandArgs(trailingOnly = FALSE), fixed = FALSE))) {
  tryCatch(
    run_export_prototype_aligned_data(),
    error = function(error) {
      stop("Prototype-aligned data export failed: ", conditionMessage(error), call. = FALSE)
    }
  )
}
