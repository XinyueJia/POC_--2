source("spec/analysis_spec.R")
source("R/generate_stan_data.R")

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

brms_mcmc_settings <- function(analysis_spec, mode = c("quick", "full")) {
  mode <- match.arg(mode)
  if (mode == "full") {
    return(list(
      mode = mode,
      chains = analysis_spec$mcmc$chains,
      iter = analysis_spec$mcmc$iter,
      warmup = analysis_spec$mcmc$warmup,
      seed = analysis_spec$mcmc$seed
    ))
  }

  list(
    mode = mode,
    chains = 2L,
    iter = 1000L,
    warmup = 500L,
    seed = analysis_spec$mcmc$seed
  )
}

write_brms_reference_failure <- function(reason, output_path = "outputs/prototype_reference_summary.json") {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to write prototype reference summary JSON.", call. = FALSE)
  }

  failure <- list(
    status = "failed",
    reference_engine = "brms",
    reason = reason,
    next_step = "Install/configure brms/rstan or reduce MCMC settings for local validation."
  )

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(failure, output_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(output_path)
}

assert_brms_runtime <- function() {
  missing_packages <- c("brms", "posterior", "jsonlite", "survival")
  missing_packages <- missing_packages[!vapply(missing_packages, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))]
  if (length(missing_packages) > 0) {
    stop("Missing required R package(s): ", paste(missing_packages, collapse = ", "), call. = FALSE)
  }
}

load_brms_reference_data <- function(path = "data/preprocessed_demo.rds") {
  if (!file.exists(path)) {
    stop(
      "Prototype-aligned data not found: ", path,
      ". Run Rscript R/run_prototype_aligned_validation.R first.",
      call. = FALSE
    )
  }

  data <- as.data.frame(readRDS(path))
  required_columns(data, c("trt", "bayes_w", "binary_y", "cont_y", "time", "status"), "brms reference data")
  data$trt <- as.integer(data$trt)
  data$binary_y <- as.integer(data$binary_y)
  data$status <- as.integer(data$status)
  data
}

prepare_brms_survival_data <- function(data, analysis_spec) {
  weights <- as.numeric(data$bayes_w)
  required_columns(data, c("trt", "time", "status"), "brms survival reference data")
  data$.design_source_row <- seq_len(nrow(data))

  split_data <- survival::survSplit(
    data = data,
    cut = analysis_spec$survival$cut_points,
    end = "time",
    event = "status",
    start = "start",
    id = ".design_split_id"
  )

  split_data$exposure <- split_data$time - split_data$start
  split_data$event <- as.integer(split_data$status)
  split_data$event_piece <- split_data$event
  split_data$interval <- findInterval(split_data$start, analysis_spec$survival$cut_points) + 1L
  split_data$interval <- pmax(1L, pmin(as.integer(split_data$interval), length(analysis_spec$survival$cut_points) + 1L))
  split_data$interval <- factor(split_data$interval)
  split_data$bayes_w <- as.numeric(weights[split_data$.design_source_row])
  split_data
}

extract_brms_treatment_draws <- function(fit) {
  draw_frame <- as.data.frame(posterior::as_draws_df(fit))
  candidates <- c("b_trt", "b_trt1", "b_trtTRUE")
  found <- intersect(candidates, names(draw_frame))

  if (length(found) == 0) {
    found <- names(draw_frame)[grepl("^b_trt", names(draw_frame))]
  }
  if (length(found) == 0) {
    stop(
      "Treatment coefficient draws not found in brms output. Available b_ columns: ",
      paste(names(draw_frame)[grepl("^b_", names(draw_frame))], collapse = ", "),
      call. = FALSE
    )
  }

  as.numeric(draw_frame[[found[[1]]]])
}

extract_brms_diagnostics <- function(fit, analysis_spec) {
  draw_summary <- posterior::summarise_draws(fit)
  draw_summary <- as.data.frame(draw_summary)
  monitored <- draw_summary[grepl("^(b_|Intercept|sigma)", draw_summary$variable), , drop = FALSE]
  if (nrow(monitored) == 0) {
    monitored <- draw_summary
  }

  rhat_col <- intersect(c("rhat", "Rhat"), names(monitored))[[1]]
  ess_bulk_col <- intersect(c("ess_bulk", "Bulk_ESS"), names(monitored))[[1]]
  ess_tail_col <- intersect(c("ess_tail", "Tail_ESS"), names(monitored))[[1]]

  rhat_max <- max(as.numeric(monitored[[rhat_col]]), na.rm = TRUE)
  ess_bulk_min <- min(as.numeric(monitored[[ess_bulk_col]]), na.rm = TRUE)
  ess_tail_min <- min(as.numeric(monitored[[ess_tail_col]]), na.rm = TRUE)

  n_divergent <- NA_integer_
  sampler_params <- tryCatch(
    rstan::get_sampler_params(fit$fit, inc_warmup = FALSE),
    error = function(error) NULL
  )
  if (!is.null(sampler_params)) {
    n_divergent <- sum(vapply(
      sampler_params,
      function(chain_params) {
        if ("divergent__" %in% colnames(chain_params)) {
          sum(chain_params[, "divergent__"], na.rm = TRUE)
        } else {
          0
        }
      },
      numeric(1)
    ))
  }

  diagnostics <- list(
    rhat_max = unname(rhat_max),
    ess_bulk_min = unname(ess_bulk_min),
    ess_tail_min = unname(ess_tail_min),
    n_divergent = as.integer(n_divergent)
  )
  diagnostics$diagnostics_passed <- isTRUE(diagnostics$rhat_max <= analysis_spec$diagnostics$rhat_threshold) &&
    isTRUE(diagnostics$ess_bulk_min >= analysis_spec$diagnostics$ess_bulk_min) &&
    isTRUE(diagnostics$ess_tail_min >= analysis_spec$diagnostics$ess_tail_min) &&
    isTRUE(diagnostics$n_divergent <= analysis_spec$diagnostics$divergent_allowed)

  diagnostics
}

summarize_brms_outcome <- function(fit, outcome_type, analysis_spec, run_id) {
  beta_draws <- extract_brms_treatment_draws(fit)
  estimand <- switch(
    outcome_type,
    binary = "OR",
    continuous = "Mean difference",
    survival = "HR"
  )
  effect_draws <- switch(
    outcome_type,
    binary = exp(beta_draws),
    continuous = beta_draws,
    survival = exp(beta_draws)
  )
  benefit_probability <- switch(
    outcome_type,
    binary = mean(effect_draws < 1, na.rm = TRUE),
    continuous = mean(effect_draws < 0, na.rm = TRUE),
    survival = mean(effect_draws < 1, na.rm = TRUE)
  )
  ci <- stats::quantile(effect_draws, probs = c(0.025, 0.975), na.rm = TRUE)

  list(
    run_id = run_id,
    model_name = analysis_spec$model_name,
    outcome_type = outcome_type,
    estimand = estimand,
    posterior_mean = mean(effect_draws, na.rm = TRUE),
    posterior_median = stats::median(effect_draws, na.rm = TRUE),
    ci_95_lower = unname(ci[[1]]),
    ci_95_upper = unname(ci[[2]]),
    benefit_probability = benefit_probability,
    diagnostics = extract_brms_diagnostics(fit, analysis_spec),
    warnings = list()
  )
}

fit_brms_reference_models <- function(data, analysis_spec, settings) {
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

  detected_cores <- parallel::detectCores()
  if (is.na(detected_cores) || detected_cores < 1) {
    detected_cores <- 1L
  }
  cores <- min(settings$chains, detected_cores)

  binary_fit <- brms::brm(
    formula = brms::bf(binary_y | weights(bayes_w) ~ trt),
    data = data,
    family = brms::bernoulli(link = "logit"),
    prior = priors_binary,
    chains = settings$chains,
    iter = settings$iter,
    warmup = settings$warmup,
    cores = cores,
    seed = settings$seed,
    backend = "rstan",
    refresh = 0
  )

  continuous_fit <- brms::brm(
    formula = brms::bf(cont_y | weights(bayes_w) ~ trt),
    data = data,
    family = stats::gaussian(),
    prior = priors_cont,
    chains = settings$chains,
    iter = settings$iter,
    warmup = settings$warmup,
    cores = cores,
    seed = settings$seed,
    backend = "rstan",
    refresh = 0
  )

  survival_data <- prepare_brms_survival_data(data, analysis_spec)
  survival_fit <- brms::brm(
    formula = brms::bf(event_piece | weights(bayes_w) ~ trt + interval + offset(log(exposure))),
    data = survival_data,
    family = stats::poisson(),
    prior = priors_surv,
    chains = settings$chains,
    iter = settings$iter,
    warmup = settings$warmup,
    cores = cores,
    seed = settings$seed,
    backend = "rstan",
    refresh = 0
  )

  list(binary = binary_fit, continuous = continuous_fit, survival = survival_fit)
}

run_brms_reference_validation <- function(mode = c("quick", "full"), output_path = "outputs/prototype_reference_summary.json") {
  mode <- match.arg(mode)
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to write prototype reference summary JSON.", call. = FALSE)
  }

  tryCatch(
    {
      assert_brms_runtime()
      data <- load_brms_reference_data()
      settings <- brms_mcmc_settings(analysis_spec, mode = mode)
      run_id <- paste0("brms_reference_", format(Sys.time(), "%Y%m%d_%H%M%S"))
      fits <- fit_brms_reference_models(data, analysis_spec, settings)

      outcomes <- lapply(names(fits), function(outcome_type) {
        summarize_brms_outcome(fits[[outcome_type]], outcome_type, analysis_spec, run_id)
      })

      reference_summary <- list(
        run_id = run_id,
        model_name = analysis_spec$model_name,
        analysis_spec_version = analysis_spec$version,
        reference_engine = "brms",
        data_source = "prototype_aligned_simulated_data",
        brms_mode = settings$mode,
        chains = settings$chains,
        iter = settings$iter,
        warmup = settings$warmup,
        seed = settings$seed,
        outcomes = outcomes
      )

      dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
      jsonlite::write_json(reference_summary, output_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
      message("Generated brms prototype reference summary: ", output_path)
      invisible(output_path)
    },
    error = function(error) {
      write_brms_reference_failure(conditionMessage(error), output_path = output_path)
      message("brms reference validation failed: ", conditionMessage(error))
      invisible(output_path)
    }
  )
}

run_brms_reference_validation_cli <- function() {
  mode <- "quick"
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 0 && args[[1]] %in% c("quick", "full")) {
    mode <- args[[1]]
  }
  run_brms_reference_validation(mode = mode)
}

if (any(grepl("R/run_brms_reference_validation.R$", commandArgs(trailingOnly = FALSE), fixed = FALSE))) {
  run_brms_reference_validation_cli()
}
