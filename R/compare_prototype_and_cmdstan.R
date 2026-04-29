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
    prototype_mean <- prototype_outcomes[[outcome_type]]$posterior_mean
    cmdstan_mean <- cmdstan_outcomes[[outcome_type]]$posterior_mean
    prototype_direction <- effect_direction(outcome_type, prototype_mean)
    cmdstan_direction <- effect_direction(outcome_type, cmdstan_mean)

    list(
      outcome_type = outcome_type,
      prototype_posterior_mean = prototype_mean,
      cmdstan_posterior_mean = cmdstan_mean,
      prototype_direction = prototype_direction,
      cmdstan_direction = cmdstan_direction,
      direction_consistent = identical(prototype_direction, cmdstan_direction),
      cmdstan_diagnostics_passed = diagnostics_object$diagnostics[[outcome_type]]$diagnostics_passed %||% NA
    )
  })

  list(
    comparison_status = "completed",
    mode = "real_prototype_reference",
    comparisons = comparisons,
    all_directions_consistent = all(vapply(comparisons, function(x) isTRUE(x$direction_consistent), logical(1))),
    diagnostics_passed = diagnostics_object$all_diagnostics_passed %||% NA
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

  report <- if (identical(prototype_summary$status, "not_run")) {
    list(
      comparison_status = "not_run",
      mode = "placeholder_prototype_reference",
      cmdstan_validation_status = if (is.null(cmdstan_summary)) "summary_not_found" else "summary_found",
      message = "CmdStan validation can be run on prototype-aligned simulated data; full brms-vs-CmdStan numerical comparison has not been executed in v0.1.",
      next_step = "Rerun the Rmd/brms prototype or export a real prototype reference summary, then rerun R/compare_prototype_and_cmdstan.R.",
      expected_comparison = prototype_summary$expected_comparison,
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
