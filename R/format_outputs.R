finite_or_na <- function(x, fn) {
  x <- x[is.finite(x)]
  if (length(x) == 0) {
    return(NA_real_)
  }
  fn(x)
}

extract_beta_trt_draws <- function(fit) {
  draw_frame <- NULL

  draws_method <- fit$draws
  if (is.function(draws_method)) {
    draw_frame <- tryCatch(
      {
        draws <- draws_method()
        if (requireNamespace("posterior", quietly = TRUE)) {
          as.data.frame(posterior::as_draws_df(draws))
        } else {
          as.data.frame(draws)
        }
      },
      error = function(error) NULL
    )
  }

  if (is.null(draw_frame) && !is.null(fit$post_warmup_draws)) {
    draw_frame <- if (requireNamespace("posterior", quietly = TRUE)) {
      as.data.frame(posterior::as_draws_df(fit$post_warmup_draws))
    } else {
      as.data.frame(fit$post_warmup_draws)
    }
  }

  if (is.null(draw_frame) && is.data.frame(fit)) {
    draw_frame <- fit
  }

  if (!is.null(draw_frame)) {
    beta_columns <- names(draw_frame)[names(draw_frame) == "beta_trt"]
    if (length(beta_columns) == 0) {
      beta_columns <- names(draw_frame)[grepl("(^|[.])beta_trt($|[.])", names(draw_frame))]
    }
    if (length(beta_columns) > 0) {
      return(as.numeric(draw_frame[[beta_columns[[1]]]]))
    }

    legacy_columns <- names(draw_frame)[names(draw_frame) == "b_trt"]
    if (length(legacy_columns) > 0) {
      return(as.numeric(draw_frame[[legacy_columns[[1]]]]))
    }
  }

  stop("Treatment coefficient draws not found. Expected 'beta_trt'.", call. = FALSE)
}

extract_diagnostics <- function(fit) {
  summary_frame <- tryCatch(fit$summary(), error = function(error) NULL)

  rhat_max <- NA_real_
  ess_bulk_min <- NA_real_
  ess_tail_min <- NA_real_

  if (is.data.frame(summary_frame)) {
    if ("rhat" %in% names(summary_frame)) {
      rhat_max <- finite_or_na(summary_frame$rhat, max)
    }
    if ("ess_bulk" %in% names(summary_frame)) {
      ess_bulk_min <- finite_or_na(summary_frame$ess_bulk, min)
    }
    if ("ess_tail" %in% names(summary_frame)) {
      ess_tail_min <- finite_or_na(summary_frame$ess_tail, min)
    }
  }

  n_divergent <- NA_integer_
  sampler_diag <- tryCatch(fit$sampler_diagnostics(), error = function(error) NULL)
  if (!is.null(sampler_diag)) {
    diag_array <- as.array(sampler_diag)
    diag_names <- dimnames(diag_array)[[length(dim(diag_array))]]
    divergent_index <- match("divergent__", diag_names)
    if (!is.na(divergent_index)) {
      n_divergent <- sum(diag_array[, , divergent_index], na.rm = TRUE)
    }
  }

  list(
    rhat_max = rhat_max,
    ess_bulk_min = ess_bulk_min,
    ess_tail_min = ess_tail_min,
    n_divergent = as.integer(n_divergent)
  )
}

diagnostics_pass <- function(diagnostics, analysis_spec) {
  thresholds <- analysis_spec$diagnostics
  isTRUE(diagnostics$rhat_max <= thresholds$rhat_threshold) &&
    isTRUE(diagnostics$ess_bulk_min >= thresholds$ess_bulk_min) &&
    isTRUE(diagnostics$ess_tail_min >= thresholds$ess_tail_min) &&
    isTRUE(diagnostics$n_divergent <= thresholds$divergent_allowed)
}

format_single_output <- function(fit, outcome_type, analysis_spec, run_metadata) {
  outcome_type <- match.arg(outcome_type, c("binary", "continuous", "survival"))
  beta_draws <- extract_beta_trt_draws(fit)

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
  diagnostics <- extract_diagnostics(fit)
  diagnostics$diagnostics_passed <- diagnostics_pass(diagnostics, analysis_spec)

  list(
    outcome_type = outcome_type,
    estimand = estimand,
    posterior_mean = mean(effect_draws, na.rm = TRUE),
    posterior_median = stats::median(effect_draws, na.rm = TRUE),
    ci_95_lower = unname(ci[[1]]),
    ci_95_upper = unname(ci[[2]]),
    benefit_probability = benefit_probability,
    diagnostics = diagnostics,
    warnings = list(),
    run_id = run_metadata$run_id
  )
}

write_metadata <- function(metadata, output_path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to write metadata JSON.")
  }
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(metadata, output_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(output_path)
}

write_diagnostics <- function(diagnostics, output_path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to write diagnostics JSON.")
  }
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(diagnostics, output_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(output_path)
}

format_all_outputs <- function(fit_list, analysis_spec, output_dir = "outputs") {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to format output JSON.")
  }

  fits <- if (!is.null(fit_list$fits)) fit_list$fits else fit_list
  run_metadata <- if (!is.null(fit_list$run_metadata)) fit_list$run_metadata else list(
    run_id = build_design_run_id(analysis_spec),
    model_name = analysis_spec$model_name,
    analysis_spec_version = analysis_spec$version,
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  summaries <- list()
  diagnostics_by_outcome <- list()
  for (outcome_type in names(fits)) {
    summaries[[outcome_type]] <- format_single_output(fits[[outcome_type]], outcome_type, analysis_spec, run_metadata)
    diagnostics_by_outcome[[outcome_type]] <- summaries[[outcome_type]]$diagnostics
  }

  output_files <- analysis_spec$paths$output_files
  summary_path <- file.path(output_dir, if (!is.null(output_files$summary)) output_files$summary else "summary_output.json")
  metadata_path <- file.path(output_dir, if (!is.null(output_files$metadata)) output_files$metadata else "metadata.json")
  diagnostics_path <- file.path(output_dir, if (!is.null(output_files$diagnostics)) output_files$diagnostics else "diagnostics.json")

  summary_object <- list(
    run_id = run_metadata$run_id,
    model_name = analysis_spec$model_name,
    analysis_spec_version = analysis_spec$version,
    outcomes = unname(summaries)
  )

  output_paths <- list(
    summary_output = summary_path,
    metadata = metadata_path,
    diagnostics = diagnostics_path
  )

  metadata <- run_metadata
  metadata$model_name <- analysis_spec$model_name
  metadata$analysis_spec_version <- analysis_spec$version
  metadata$output_paths <- output_paths

  diagnostics_object <- list(
    run_id = run_metadata$run_id,
    diagnostics = diagnostics_by_outcome,
    all_diagnostics_passed = all(vapply(
      diagnostics_by_outcome,
      function(x) isTRUE(x$diagnostics_passed),
      logical(1)
    ))
  )

  jsonlite::write_json(summary_object, summary_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  write_metadata(metadata, metadata_path)
  write_diagnostics(diagnostics_object, diagnostics_path)

  if (isTRUE(analysis_spec$diagnostics$stop_on_failure) && !isTRUE(diagnostics_object$all_diagnostics_passed)) {
    stop("Diagnostics failed. See ", diagnostics_path, " for details.", call. = FALSE)
  }

  list(
    summary_output = summary_path,
    metadata = metadata_path,
    diagnostics = diagnostics_path,
    summary = summary_object,
    diagnostics_object = diagnostics_object
  )
}
