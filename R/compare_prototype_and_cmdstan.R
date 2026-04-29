prototype_reference_placeholder <- function() {
  list(
    status = "not_run",
    reason = "Full brms prototype rerun is optional in v0.1",
    expected_comparison = list(
      "binary OR direction",
      "continuous mean difference direction",
      "survival HR direction",
      "posterior interval broad agreement",
      "diagnostics pass/fail consistency"
    )
  )
}

write_prototype_reference_placeholder <- function(output_path = "outputs/prototype_reference_summary.json") {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to write prototype reference summary JSON.", call. = FALSE)
  }
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(prototype_reference_placeholder(), output_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(output_path)
}

effect_direction <- function(outcome_type, value) {
  if (is.null(value) || is.na(value)) {
    return(NA_character_)
  }
  if (outcome_type %in% c("binary", "survival")) {
    return(ifelse(value < 1, "benefit", ifelse(value > 1, "harm", "null")))
  }
  if (outcome_type == "continuous") {
    return(ifelse(value < 0, "benefit", ifelse(value > 0, "harm", "null")))
  }
  NA_character_
}

safe_numeric <- function(x) {
  if (is.null(x)) {
    return(NA_real_)
  }
  as.numeric(x)
}

relative_difference <- function(reference, candidate, tolerance = 1e-8) {
  reference <- safe_numeric(reference)
  candidate <- safe_numeric(candidate)
  if (!is.finite(reference) || abs(reference) < tolerance) {
    return(NULL)
  }
  abs(candidate - reference) / abs(reference)
}

intervals_overlap <- function(a_lower, a_upper, b_lower, b_upper) {
  a_lower <- safe_numeric(a_lower)
  a_upper <- safe_numeric(a_upper)
  b_lower <- safe_numeric(b_lower)
  b_upper <- safe_numeric(b_upper)
  if (any(!is.finite(c(a_lower, a_upper, b_lower, b_upper)))) {
    return(NA)
  }
  max(a_lower, b_lower) <= min(a_upper, b_upper)
}

named_outcomes <- function(summary_object) {
  outcomes <- summary_object$outcomes %||% list()
  names(outcomes) <- vapply(outcomes, function(x) x$outcome_type %||% "", character(1))
  outcomes
}

compare_real_reference <- function(prototype_summary, cmdstan_summary, diagnostics_object) {
  prototype_outcomes <- named_outcomes(prototype_summary)
  cmdstan_outcomes <- named_outcomes(cmdstan_summary)

  outcome_names <- intersect(names(prototype_outcomes), names(cmdstan_outcomes))
  comparisons <- lapply(outcome_names, function(outcome_type) {
    brms <- prototype_outcomes[[outcome_type]]
    cmdstan <- cmdstan_outcomes[[outcome_type]]
    brms_mean <- safe_numeric(brms$posterior_mean)
    cmdstan_mean <- safe_numeric(cmdstan$posterior_mean)
    brms_direction <- effect_direction(outcome_type, brms_mean)
    cmdstan_direction <- effect_direction(outcome_type, cmdstan_mean)
    overlap <- intervals_overlap(brms$ci_95_lower, brms$ci_95_upper, cmdstan$ci_95_lower, cmdstan$ci_95_upper)
    brms_diagnostics_passed <- brms$diagnostics$diagnostics_passed %||% NA
    cmdstan_diagnostics_passed <- cmdstan$diagnostics$diagnostics_passed %||%
      diagnostics_object$diagnostics[[outcome_type]]$diagnostics_passed %||%
      NA

    list(
      outcome_type = outcome_type,
      estimand = cmdstan$estimand %||% brms$estimand,
      brms_posterior_mean = brms_mean,
      cmdstan_posterior_mean = cmdstan_mean,
      absolute_difference = abs(cmdstan_mean - brms_mean),
      relative_difference = relative_difference(brms_mean, cmdstan_mean),
      brms_direction = brms_direction,
      cmdstan_direction = cmdstan_direction,
      direction_consistent = identical(brms_direction, cmdstan_direction),
      brms_ci_95_lower = safe_numeric(brms$ci_95_lower),
      brms_ci_95_upper = safe_numeric(brms$ci_95_upper),
      cmdstan_ci_95_lower = safe_numeric(cmdstan$ci_95_lower),
      cmdstan_ci_95_upper = safe_numeric(cmdstan$ci_95_upper),
      intervals_overlap = overlap,
      brms_benefit_probability = safe_numeric(brms$benefit_probability),
      cmdstan_benefit_probability = safe_numeric(cmdstan$benefit_probability),
      benefit_probability_difference = abs(safe_numeric(cmdstan$benefit_probability) - safe_numeric(brms$benefit_probability)),
      brms_diagnostics_passed = brms_diagnostics_passed,
      cmdstan_diagnostics_passed = cmdstan_diagnostics_passed,
      both_diagnostics_passed = isTRUE(brms_diagnostics_passed) && isTRUE(cmdstan_diagnostics_passed)
    )
  })

  all_directions_consistent <- all(vapply(comparisons, function(x) isTRUE(x$direction_consistent), logical(1)))
  all_intervals_overlap <- all(vapply(comparisons, function(x) isTRUE(x$intervals_overlap), logical(1)))
  all_diagnostics_passed <- all(vapply(comparisons, function(x) isTRUE(x$both_diagnostics_passed), logical(1)))

  list(
    comparison_status = "completed",
    mode = "brms_vs_cmdstan",
    data_source = "prototype_aligned_simulated_data",
    comparisons = comparisons,
    overall = list(
      all_directions_consistent = all_directions_consistent,
      all_intervals_overlap = all_intervals_overlap,
      all_diagnostics_passed = all_diagnostics_passed
    ),
    warnings = list()
  )
}

compare_prototype_and_cmdstan <- function(
  prototype_reference_path = "outputs/prototype_reference_summary.json",
  cmdstan_summary_path = "outputs/summary_output.json",
  diagnostics_path = "outputs/diagnostics.json",
  output_path = "outputs/prototype_cmdstan_comparison.json"
) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to compare prototype and CmdStan outputs.", call. = FALSE)
  }

  if (!file.exists(prototype_reference_path)) {
    write_prototype_reference_placeholder(prototype_reference_path)
  }

  prototype_summary <- jsonlite::read_json(prototype_reference_path, simplifyVector = FALSE)
  cmdstan_summary <- if (file.exists(cmdstan_summary_path)) {
    jsonlite::read_json(cmdstan_summary_path, simplifyVector = FALSE)
  } else {
    NULL
  }
  diagnostics_object <- if (file.exists(diagnostics_path)) {
    jsonlite::read_json(diagnostics_path, simplifyVector = FALSE)
  } else {
    list(all_diagnostics_passed = NA, diagnostics = list())
  }

  report <- if (identical(prototype_summary$status, "not_run") || identical(prototype_summary$status, "failed")) {
    list(
      comparison_status = prototype_summary$status %||% "not_run",
      mode = if (identical(prototype_summary$status, "failed")) "failed_prototype_reference" else "placeholder_prototype_reference",
      cmdstan_validation_status = if (is.null(cmdstan_summary)) "summary_not_found" else "summary_found",
      message = prototype_summary$reason %||% "CmdStan validation can be run on prototype-aligned simulated data; full brms-vs-CmdStan numerical comparison has not been executed.",
      next_step = prototype_summary$next_step %||% "Run Rscript R/run_brms_vs_cmdstan_comparison.R after brms/rstan are available.",
      expected_comparison = prototype_summary$expected_comparison %||% list(
        "binary OR direction",
        "continuous mean difference direction",
        "survival HR direction",
        "posterior interval broad agreement",
        "diagnostics pass/fail consistency"
      ),
      diagnostics_passed = diagnostics_object$all_diagnostics_passed %||% NA
    )
  } else {
    compare_real_reference(prototype_summary, cmdstan_summary, diagnostics_object)
  }

  report$prototype_reference_path <- prototype_reference_path
  report$cmdstan_summary_path <- cmdstan_summary_path
  report$diagnostics_path <- diagnostics_path
  report$generated_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(report, output_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(output_path)
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

run_compare_prototype_and_cmdstan <- function() {
  output_path <- compare_prototype_and_cmdstan()
  message("Generated prototype/CmdStan comparison report: ", output_path)
  invisible(output_path)
}

if (any(grepl("R/compare_prototype_and_cmdstan.R$", commandArgs(trailingOnly = FALSE), fixed = FALSE))) {
  tryCatch(
    run_compare_prototype_and_cmdstan(),
    error = function(error) {
      stop("Prototype/CmdStan comparison failed: ", conditionMessage(error), call. = FALSE)
    }
  )
}
