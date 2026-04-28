default_if_null <- function(value, fallback) {
  if (is.null(value)) fallback else value
}

get_object_member <- function(object, member_name) {
  if (is.list(object) || is.environment(object)) {
    return(object[[member_name]])
  }

  NULL
}

extract_treatment_draws <- function(stan_fit, candidate_parameters = c("b_trt", "beta_trt", "trt")) {
  if (is.numeric(stan_fit)) {
    return(as.numeric(stan_fit))
  }

  draw_data <- NULL
  draws_member <- get_object_member(stan_fit, "draws")
  if (is.function(draws_member)) {
    draw_data <- tryCatch(draws_member(), error = function(error) NULL)
  }

  if (is.null(draw_data) && is.data.frame(stan_fit)) {
    draw_data <- stan_fit
  }

  if (is.null(draw_data) && is.list(stan_fit)) {
    if (!is.null(stan_fit$draws) && is.data.frame(stan_fit$draws)) {
      draw_data <- stan_fit$draws
    }
  }

  if (is.null(draw_data)) {
    stop("Unable to extract posterior draws from stan_fit")
  }

  draw_frame <- as.data.frame(draw_data)
  for (parameter_name in candidate_parameters) {
    if (parameter_name %in% names(draw_frame)) {
      return(as.numeric(draw_frame[[parameter_name]]))
    }
  }

  stop("No treatment coefficient draw found. Expected one of: ", paste(candidate_parameters, collapse = ", "))
}

summarize_step2_posterior <- function(draws, outcome, effect, transform = identity, benefit_rule) {
  effect_draws <- transform(draws)
  ci <- stats::quantile(effect_draws, probs = c(0.025, 0.975), na.rm = TRUE)

  list(
    outcome = outcome,
    effect = effect,
    post_mean = mean(effect_draws, na.rm = TRUE),
    post_median = stats::median(effect_draws, na.rm = TRUE),
    conf.low = unname(ci[1]),
    conf.high = unname(ci[2]),
    post_prob_benefit = mean(benefit_rule(effect_draws), na.rm = TRUE)
  )
}

extract_step2_diagnostics <- function(stan_fit) {
  summary_frame <- NULL

  summary_member <- get_object_member(stan_fit, "summary")
  if (is.function(summary_member)) {
    summary_frame <- tryCatch(summary_member(), error = function(error) NULL)
  }

  if (is.null(summary_frame) && is.data.frame(stan_fit)) {
    summary_frame <- stan_fit
  }

  rhat_max <- NA_real_
  ess_bulk_min <- NA_real_
  ess_tail_min <- NA_real_

  if (is.data.frame(summary_frame)) {
    if ("rhat" %in% names(summary_frame)) {
      rhat_max <- max(summary_frame$rhat, na.rm = TRUE)
    }
    if ("ess_bulk" %in% names(summary_frame)) {
      ess_bulk_min <- min(summary_frame$ess_bulk, na.rm = TRUE)
    }
    if ("ess_tail" %in% names(summary_frame)) {
      ess_tail_min <- min(summary_frame$ess_tail, na.rm = TRUE)
    }
  }

  n_divergent <- NA_integer_
  sampler_diagnostics_member <- get_object_member(stan_fit, "sampler_diagnostics")
  if (is.function(sampler_diagnostics_member)) {
    diag_result <- tryCatch(sampler_diagnostics_member(), error = function(error) NULL)
    if (!is.null(diag_result)) {
      diag_array <- as.array(diag_result)
      if (length(dim(diag_array)) >= 3) {
        divergent_slice <- diag_array[, , dim(diag_array)[3], drop = TRUE]
        if (is.matrix(divergent_slice) || is.array(divergent_slice)) {
          n_divergent <- sum(divergent_slice[, "divergent__"], na.rm = TRUE)
        }
      }
    }
  }

  list(
    rhat_max = rhat_max,
    ess_bulk_min = ess_bulk_min,
    ess_tail_min = ess_tail_min,
    n_divergent = n_divergent
  )
}

build_step2_summary_output <- function(stan_fit, outcome_type, run_metadata = list()) {
  outcome_type <- match.arg(outcome_type, choices = c("binary", "continuous", "survival"))

  effect_name <- switch(
    outcome_type,
    binary = "OR",
    continuous = "Mean difference",
    survival = "HR"
  )

  transform_fn <- switch(
    outcome_type,
    binary = exp,
    continuous = identity,
    survival = exp
  )

  benefit_rule <- switch(
    outcome_type,
    binary = function(x) x < 1,
    continuous = function(x) x < 0,
    survival = function(x) x < 1
  )

  parameter_name <- switch(
    outcome_type,
    binary = "b_trt",
    continuous = "b_trt",
    survival = "b_trt"
  )

  draws <- extract_treatment_draws(stan_fit, candidate_parameters = c(parameter_name, "beta_trt", "trt"))
  posterior_result <- summarize_step2_posterior(
    draws = draws,
    outcome = tools::toTitleCase(outcome_type),
    effect = effect_name,
    transform = transform_fn,
    benefit_rule = benefit_rule
  )

  diagnostics <- extract_step2_diagnostics(stan_fit)
  warnings <- default_if_null(run_metadata$warnings, character())

  list(
    run_id = default_if_null(run_metadata$run_id, NA_character_),
    model_name = default_if_null(run_metadata$model_name, NA_character_),
    outcome_type = outcome_type,
    estimand = effect_name,
    posterior_mean = posterior_result$post_mean,
    posterior_median = posterior_result$post_median,
    ci_95_lower = posterior_result$conf.low,
    ci_95_upper = posterior_result$conf.high,
    benefit_probability = posterior_result$post_prob_benefit,
    rhat_max = diagnostics$rhat_max,
    ess_bulk_min = diagnostics$ess_bulk_min,
    n_divergent = diagnostics$n_divergent,
    warnings = warnings,
    result = posterior_result,
    diagnostics = diagnostics
  )
}

format_stan_output <- function(stan_fit, outcome_type, run_metadata = list()) {
  build_step2_summary_output(stan_fit, outcome_type = outcome_type, run_metadata = run_metadata)
}

write_step2_summary_output <- function(summary_object, output_path) {
  output_directory <- dirname(output_path)
  if (!dir.exists(output_directory)) {
    dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  }

  jsonlite::write_json(summary_object, output_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(output_path)
}
