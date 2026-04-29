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
