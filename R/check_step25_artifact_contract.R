if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required for Step 2.5 artifact contract checks.", call. = FALSE)
}

checks <- list()

add_check <- function(name, passed, details = NULL) {
  checks[[length(checks) + 1L]] <<- list(
    name = name,
    passed = isTRUE(passed),
    details = if (is.null(details)) "" else as.character(details)
  )
}

read_json_file <- function(path) {
  if (!file.exists(path)) {
    stop("Missing required file: ", path, call. = FALSE)
  }
  jsonlite::read_json(path, simplifyVector = FALSE)
}

as_numeric_vector <- function(x) {
  as.numeric(unlist(x, use.names = FALSE))
}

as_integer_vector <- function(x) {
  as.integer(unlist(x, use.names = FALSE))
}

has_fields <- function(x, fields) {
  missing <- setdiff(fields, names(x))
  list(ok = length(missing) == 0L, missing = missing)
}

check_binary_or_continuous <- function(path, outcome_type) {
  dat <- read_json_file(path)
  required <- c("N", "y", "trt", "weights")
  fields <- has_fields(dat, required)
  add_check(
    paste0(outcome_type, "_required_fields"),
    fields$ok,
    if (fields$ok) "all required fields present" else paste(fields$missing, collapse = ", ")
  )
  if (!fields$ok) {
    return(invisible(NULL))
  }

  n <- as.integer(dat$N)
  y <- as_numeric_vector(dat$y)
  trt <- as_integer_vector(dat$trt)
  weights <- as_numeric_vector(dat$weights)

  add_check(paste0(outcome_type, "_N_valid"), length(n) == 1L && !is.na(n) && n >= 1L)
  add_check(paste0(outcome_type, "_y_length"), length(y) == n)
  add_check(paste0(outcome_type, "_trt_length"), length(trt) == n)
  add_check(paste0(outcome_type, "_weights_length"), length(weights) == n)
  add_check(paste0(outcome_type, "_trt_values"), all(trt %in% c(0L, 1L)))
  add_check(paste0(outcome_type, "_weights_nonnegative"), all(is.finite(weights) & weights >= 0))

  if (identical(outcome_type, "binary")) {
    add_check("binary_y_values", all(as_integer_vector(dat$y) %in% c(0L, 1L)))
  } else {
    add_check("continuous_y_numeric", all(is.finite(y)))
  }
}

check_survival <- function(path) {
  dat <- read_json_file(path)
  required <- c("N", "J", "event", "interval", "trt", "exposure", "weights")
  fields <- has_fields(dat, required)
  add_check(
    "survival_required_fields",
    fields$ok,
    if (fields$ok) "all required fields present" else paste(fields$missing, collapse = ", ")
  )
  if (!fields$ok) {
    return(invisible(NULL))
  }

  n <- as.integer(dat$N)
  j <- as.integer(dat$J)
  event <- as_integer_vector(dat$event)
  interval <- as_integer_vector(dat$interval)
  trt <- as_integer_vector(dat$trt)
  exposure <- as_numeric_vector(dat$exposure)
  weights <- as_numeric_vector(dat$weights)

  add_check("survival_N_valid", length(n) == 1L && !is.na(n) && n >= 1L)
  add_check("survival_J_valid", length(j) == 1L && !is.na(j) && j >= 1L)
  add_check("survival_event_length", length(event) == n)
  add_check("survival_interval_length", length(interval) == n)
  add_check("survival_trt_length", length(trt) == n)
  add_check("survival_exposure_length", length(exposure) == n)
  add_check("survival_weights_length", length(weights) == n)
  add_check("survival_event_values", all(event %in% c(0L, 1L)))
  add_check("survival_interval_range", all(interval >= 1L & interval <= j))
  add_check("survival_trt_values", all(trt %in% c(0L, 1L)))
  add_check("survival_exposure_positive", all(is.finite(exposure) & exposure > 0))
  add_check("survival_weights_nonnegative", all(is.finite(weights) & weights >= 0))
}

check_summary_output <- function(path) {
  summary <- read_json_file(path)
  top_fields <- has_fields(summary, c("run_id", "model_name", "analysis_spec_version", "outcomes"))
  add_check(
    "summary_top_level_fields",
    top_fields$ok,
    if (top_fields$ok) "all required fields present" else paste(top_fields$missing, collapse = ", ")
  )
  if (!top_fields$ok || length(summary$outcomes) == 0L) {
    add_check("summary_outcomes_present", FALSE, "outcomes is missing or empty")
    return(invisible(NULL))
  }

  warnings_present <- vapply(summary$outcomes, function(outcome) {
    "warnings" %in% names(outcome) && is.list(outcome$warnings)
  }, logical(1))
  add_check("summary_outcome_warnings_present", all(warnings_present))
}

check_diagnostics_output <- function(path) {
  diagnostics <- read_json_file(path)
  required <- has_fields(diagnostics, c("run_id", "diagnostics", "all_diagnostics_passed"))
  add_check(
    "diagnostics_required_fields",
    required$ok,
    if (required$ok) "all required fields present" else paste(required$missing, collapse = ", ")
  )
}

check_binary_or_continuous("data/stan_input_binary.json", "binary")
check_binary_or_continuous("data/stan_input_continuous.json", "continuous")
check_survival("data/stan_input_survival.json")
check_summary_output("outputs/summary_output.json")
check_diagnostics_output("outputs/diagnostics.json")

result <- list(
  contract_name = "step25_artifact_contract",
  contract_version = "0.1",
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  all_checks_passed = all(vapply(checks, `[[`, logical(1), "passed")),
  checks = checks
)

if (!dir.exists("outputs")) {
  dir.create("outputs", recursive = TRUE, showWarnings = FALSE)
}

jsonlite::write_json(
  result,
  "outputs/step25_artifact_contract_check.json",
  auto_unbox = TRUE,
  pretty = TRUE,
  null = "null"
)

if (!isTRUE(result$all_checks_passed)) {
  stop("Step 2.5 artifact contract check failed. See outputs/step25_artifact_contract_check.json.", call. = FALSE)
}

message("Step 2.5 artifact contract check passed: outputs/step25_artifact_contract_check.json")
