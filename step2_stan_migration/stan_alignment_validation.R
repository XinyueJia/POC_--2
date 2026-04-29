load_json_object <- function(path) {
  if (!file.exists(path)) {
    stop("JSON file not found: ", path)
  }

  jsonlite::read_json(path, simplifyVector = TRUE)
}

as_scalar_value <- function(value) {
  if (is.null(value)) {
    return(NULL)
  }

  if (is.data.frame(value)) {
    return(as.list(value[1, , drop = FALSE]))
  }

  if (is.list(value)) {
    if (!is.null(names(value)) && all(nzchar(names(value)))) {
      return(value)
    }

    if (length(value) == 1) {
      return(value[[1]])
    }
  }

  if (length(value) >= 1) {
    return(value[[1]])
  }

  value
}

normalize_outcome_label <- function(value) {
  if (is.null(value) || length(value) == 0) {
    return(NA_character_)
  }

  tolower(as.character(as_scalar_value(value)))
}

extract_reference_outcome <- function(reference_summary, outcome_type) {
  if (is.null(reference_summary$results)) {
    stop("Reference summary does not contain outcome results")
  }

  results_block <- reference_summary$results
  if (is.null(names(results_block)) && length(results_block) == 1 && is.list(results_block[[1]])) {
    results_block <- results_block[[1]]
  }

  if (is.null(results_block[[outcome_type]])) {
    stop("Reference summary does not contain outcome: ", outcome_type)
  }

  outcome_block <- results_block[[outcome_type]]
  list(
    result = as_scalar_value(outcome_block$result),
    diagnostics = as_scalar_value(outcome_block$diagnostics)
  )
}

required_step2_fields <- c(
  "run_id",
  "model_name",
  "outcome_type",
  "estimand",
  "posterior_mean",
  "posterior_median",
  "ci_95_lower",
  "ci_95_upper",
  "benefit_probability",
  "rhat_max",
  "ess_bulk_min",
  "ess_tail_min",
  "n_divergent",
  "diagnostics_passed",
  "warnings",
  "result",
  "diagnostics"
)

required_reference_result_fields <- c(
  "outcome",
  "effect",
  "post_mean",
  "post_median",
  "conf.low",
  "conf.high",
  "post_prob_benefit"
)

required_reference_diagnostic_fields <- c(
  "outcome",
  "rhat_max",
  "ess_bulk_min",
  "ess_tail_min",
  "n_divergent"
)

collect_missing_fields <- function(object, required_fields) {
  missing_fields <- setdiff(required_fields, names(object))
  if (length(missing_fields) == 0) {
    character()
  } else {
    missing_fields
  }
}

compare_numeric <- function(candidate, reference, tolerance = 1e-8) {
  if (is.null(candidate) || is.null(reference)) {
    return(FALSE)
  }

  if (is.na(candidate) && is.na(reference)) {
    return(TRUE)
  }

  isTRUE(abs(as.numeric(candidate) - as.numeric(reference)) <= tolerance)
}

compare_numeric_delta <- function(candidate, reference) {
  if (is.null(candidate) || is.null(reference)) {
    return(NA_real_)
  }

  as.numeric(candidate) - as.numeric(reference)
}

infer_step2_effect_direction <- function(posterior_mean, outcome_type) {
  if (is.null(posterior_mean) || is.na(posterior_mean)) {
    return(NA_character_)
  }

  benefit_is_lower <- outcome_type %in% c("binary", "survival")
  if (benefit_is_lower) {
    if (posterior_mean < 1) return("benefit")
    if (posterior_mean > 1) return("harm")
    return("neutral")
  }

  if (posterior_mean < 0) return("benefit")
  if (posterior_mean > 0) return("harm")
  "neutral"
}

format_step2_alignment_report <- function(validation_result) {
  if (is.null(validation_result$results)) {
    stop("Validation result does not contain suite results")
  }

  lines <- c(
    "# Step 2 Alignment Report",
    "",
    paste0("Overall passed: ", if (isTRUE(validation_result$passed)) "YES" else "NO"),
    ""
  )

  for (item in validation_result$results) {
    lines <- c(
      lines,
      paste0("## ", tools::toTitleCase(item$outcome_type)),
      paste0("- Passed: ", if (isTRUE(item$passed)) "YES" else "NO")
    )

    if (!is.null(item$summary)) {
      summary <- item$summary
      lines <- c(
        lines,
        paste0("- Candidate direction: ", summary$candidate_direction),
        paste0("- Reference direction: ", summary$reference_direction),
        paste0("- Direction match: ", if (isTRUE(summary$direction_match)) "YES" else "NO"),
        paste0("- Posterior mean delta: ", summary$posterior_mean_delta),
        paste0("- Posterior median delta: ", summary$posterior_median_delta),
        paste0("- CI low delta: ", summary$ci_95_lower_delta),
        paste0("- CI high delta: ", summary$ci_95_upper_delta),
        paste0("- Benefit probability delta: ", summary$benefit_probability_delta),
        paste0("- Rhat delta: ", summary$rhat_max_delta),
        paste0("- ESS bulk delta: ", summary$ess_bulk_min_delta),
        paste0("- ESS tail delta: ", summary$ess_tail_min_delta),
        paste0("- Divergent delta: ", summary$n_divergent_delta)
      )
    }

    lines <- c(lines, "")
  }

  paste(lines, collapse = "\n")
}

summarize_step2_alignment <- function(candidate_summary, reference_summary, outcome_type, config = NULL) {
  validation <- validate_step2_alignment(candidate_summary, reference_summary, outcome_type = outcome_type, config = config)
  reference_outcome <- validation$reference
  reference_result <- reference_outcome$result
  reference_diagnostics <- reference_outcome$diagnostics

  candidate_direction <- infer_step2_effect_direction(candidate_summary$posterior_mean, outcome_type)
  reference_direction <- infer_step2_effect_direction(reference_result$post_mean, outcome_type)

  list(
    outcome_type = outcome_type,
    passed = isTRUE(validation$passed),
    direction_match = identical(candidate_direction, reference_direction),
    candidate_direction = candidate_direction,
    reference_direction = reference_direction,
    posterior_mean_delta = compare_numeric_delta(candidate_summary$posterior_mean, reference_result$post_mean),
    posterior_median_delta = compare_numeric_delta(candidate_summary$posterior_median, reference_result$post_median),
    ci_95_lower_delta = compare_numeric_delta(candidate_summary$ci_95_lower, reference_result$conf.low),
    ci_95_upper_delta = compare_numeric_delta(candidate_summary$ci_95_upper, reference_result$conf.high),
    benefit_probability_delta = compare_numeric_delta(candidate_summary$benefit_probability, reference_result$post_prob_benefit),
    rhat_max_delta = compare_numeric_delta(candidate_summary$rhat_max, reference_diagnostics$rhat_max),
    ess_bulk_min_delta = compare_numeric_delta(candidate_summary$ess_bulk_min, reference_diagnostics$ess_bulk_min),
    ess_tail_min_delta = compare_numeric_delta(candidate_summary$ess_tail_min, reference_diagnostics$ess_tail_min),
    n_divergent_delta = compare_numeric_delta(candidate_summary$n_divergent, reference_diagnostics$n_divergent),
    checks = validation$checks
  )
}

validate_step2_alignment <- function(candidate_summary, reference_summary, outcome_type, config = NULL) {
  candidate_missing <- collect_missing_fields(candidate_summary, required_step2_fields)
  if (length(candidate_missing) > 0) {
    stop("Candidate summary is missing field(s): ", paste(candidate_missing, collapse = ", "))
  }

  reference_outcome <- extract_reference_outcome(reference_summary, outcome_type)
  reference_result <- reference_outcome$result
  reference_diagnostics <- reference_outcome$diagnostics

  if (length(collect_missing_fields(reference_result, required_reference_result_fields)) > 0) {
    stop("Reference result block is missing required field(s) for outcome: ", outcome_type)
  }

  if (length(collect_missing_fields(reference_diagnostics, required_reference_diagnostic_fields)) > 0) {
    stop("Reference diagnostics block is missing required field(s) for outcome: ", outcome_type)
  }

  checks <- list(
    outcome_label = identical(normalize_outcome_label(candidate_summary$outcome_type), normalize_outcome_label(outcome_type)),
    estimand_label = identical(as.character(candidate_summary$estimand), as.character(reference_result$effect)),
    has_result_block = is.list(candidate_summary$result),
    has_diagnostics_block = is.list(candidate_summary$diagnostics),
    diagnostics_passed_flag = isTRUE(candidate_summary$diagnostics_passed)
  )

  numeric_checks <- list(
    rhat_max = compare_numeric(candidate_summary$rhat_max, reference_diagnostics$rhat_max),
    ess_bulk_min = compare_numeric(candidate_summary$ess_bulk_min, reference_diagnostics$ess_bulk_min),
    ess_tail_min = compare_numeric(candidate_summary$ess_tail_min, reference_diagnostics$ess_tail_min),
    n_divergent = compare_numeric(candidate_summary$n_divergent, reference_diagnostics$n_divergent)
  )

  threshold_checks <- list()
  if (!is.null(config) && !is.null(config$diagnostics)) {
    threshold_checks <- list(
      rhat_within_threshold = is.na(candidate_summary$rhat_max) || candidate_summary$rhat_max <= config$diagnostics$rhat_threshold,
      ess_bulk_within_threshold = is.na(candidate_summary$ess_bulk_min) || candidate_summary$ess_bulk_min >= config$diagnostics$ess_bulk_min,
      ess_tail_within_threshold = is.na(candidate_summary$ess_tail_min) || candidate_summary$ess_tail_min >= config$diagnostics$ess_tail_min,
      divergent_within_threshold = is.na(candidate_summary$n_divergent) || candidate_summary$n_divergent <= config$diagnostics$divergent_allowed
    )
  }

  all_checks <- c(checks, numeric_checks, threshold_checks)
  passed <- all(unlist(all_checks))

  list(
    passed = passed,
    checks = all_checks,
    reference = list(result = reference_result, diagnostics = reference_diagnostics)
  )
}

validate_step2_alignment_from_files <- function(candidate_summary_path, reference_summary_path, config_path = "config/config.json", outcome_type) {
  candidate_summary <- load_json_object(candidate_summary_path)
  reference_summary <- load_json_object(reference_summary_path)
  config <- load_json_object(config_path)

  validate_step2_alignment(candidate_summary, reference_summary, outcome_type = outcome_type, config = config)
}

extract_step2_alignment_reference_suite <- function(reference_summary) {
  if (is.null(reference_summary$results) || length(reference_summary$results) == 0) {
    stop("Reference summary does not contain any outcome results")
  }

  results_block <- reference_summary$results
  if (is.null(names(results_block)) && length(results_block) == 1 && is.list(results_block[[1]])) {
    results_block <- results_block[[1]]
  }

  outcome_types <- intersect(names(results_block), c("binary", "continuous", "survival"))
  if (length(outcome_types) == 0) {
    stop("Reference summary does not contain supported outcome types")
  }

  outcome_types
}

build_step2_alignment_candidate_from_reference <- function(reference_summary, outcome_type) {
  reference_outcome <- extract_reference_outcome(reference_summary, outcome_type)
  reference_result <- reference_outcome$result
  reference_diagnostics <- reference_outcome$diagnostics

  list(
    run_id = as.character(as_scalar_value(reference_summary$run_id)),
    model_name = as.character(as_scalar_value(reference_summary$metadata$model_name)),
    outcome_type = outcome_type,
    estimand = as.character(reference_result$effect),
    posterior_mean = as.numeric(reference_result$post_mean),
    posterior_median = as.numeric(reference_result$post_median),
    ci_95_lower = as.numeric(reference_result$conf.low),
    ci_95_upper = as.numeric(reference_result$conf.high),
    benefit_probability = as.numeric(reference_result$post_prob_benefit),
    rhat_max = as.numeric(reference_diagnostics$rhat_max),
    ess_bulk_min = as.numeric(reference_diagnostics$ess_bulk_min),
    ess_tail_min = as.numeric(reference_diagnostics$ess_tail_min),
    n_divergent = as.numeric(reference_diagnostics$n_divergent),
    diagnostics_passed = isTRUE(as_scalar_value(reference_summary$metadata$diagnostics_passed)),
    warnings = character(),
    result = as.list(reference_result),
    diagnostics = as.list(reference_diagnostics)
  )
}

validate_step2_alignment_suite <- function(reference_summary, config = NULL, outcome_types = NULL) {
  if (is.null(outcome_types)) {
    outcome_types <- extract_step2_alignment_reference_suite(reference_summary)
  }

  if (is.null(config)) {
    config <- load_json_object("config/config.json")
  }

  suite_results <- lapply(outcome_types, function(outcome_type) {
    candidate_summary <- build_step2_alignment_candidate_from_reference(reference_summary, outcome_type)
    result <- summarize_step2_alignment(candidate_summary, reference_summary, outcome_type = outcome_type, config = config)
    list(
      outcome_type = outcome_type,
      passed = isTRUE(result$passed),
      summary = result,
      checks = result$checks
    )
  })

  names(suite_results) <- outcome_types

  list(
    passed = all(vapply(suite_results, function(item) isTRUE(item$passed), logical(1))),
    results = suite_results
  )
}

write_step2_alignment_report <- function(validation_result, output_path) {
  output_directory <- dirname(output_path)
  if (!dir.exists(output_directory)) {
    dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  }

  jsonlite::write_json(validation_result, output_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(output_path)
}

write_step2_alignment_markdown_report <- function(validation_result, output_path) {
  output_directory <- dirname(output_path)
  if (!dir.exists(output_directory)) {
    dir.create(output_directory, recursive = TRUE, showWarnings = FALSE)
  }

  report_text <- format_step2_alignment_report(validation_result)
  writeLines(report_text, con = output_path, useBytes = TRUE)
  invisible(output_path)
}