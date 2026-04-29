source("spec/analysis_spec.R")
source("R/generate_config.R")
source("R/generate_stan_data.R")
source("R/select_stan_model.R")
source("R/run_cmdstan_validation.R")
source("R/format_outputs.R")
source("R/export_prototype_aligned_data.R")
source("R/compare_prototype_and_cmdstan.R")

copy_if_exists <- function(from, to) {
  if (file.exists(from)) {
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
    file.copy(from, to, overwrite = TRUE)
    return(TRUE)
  }
  FALSE
}

sync_engine_package_from_step25 <- function(analysis_spec) {
  data_dir <- analysis_spec$paths$data_dir
  outputs_dir <- analysis_spec$paths$outputs_dir
  input_files <- analysis_spec$paths$stan_input_files
  output_files <- analysis_spec$paths$output_files

  copied <- list()
  for (outcome_type in names(input_files)) {
    source_path <- file.path(data_dir, input_files[[outcome_type]])
    target_path <- file.path("engine_package", "data", input_files[[outcome_type]])
    copied[[target_path]] <- copy_if_exists(source_path, target_path)
  }

  expected_map <- list(
    summary = c(output_files$summary %||% "summary_output.json", "summary_output.json"),
    metadata = c(output_files$metadata %||% "metadata.json", "metadata.json"),
    diagnostics = c(output_files$diagnostics %||% "diagnostics.json", "diagnostics.json")
  )
  for (item in expected_map) {
    source_path <- file.path(outputs_dir, item[[1]])
    target_path <- file.path("engine_package", "expected_outputs", item[[2]])
    copied[[target_path]] <- copy_if_exists(source_path, target_path)
  }

  copied
}

write_validation_report <- function(report, path = "outputs/prototype_aligned_validation_report.json") {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to write validation report JSON.", call. = FALSE)
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(report, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(path)
}

build_validation_report <- function(
  data_export,
  stan_input_paths,
  output_paths = NULL,
  diagnostics_passed = NA,
  validation_status = "not_run",
  error_message = NULL,
  engine_package_sync = list()
) {
  list(
    validation_name = "prototype_aligned_validation",
    validation_status = validation_status,
    data_source = "prototype_simulated_data",
    source_detail = data_export$data_source,
    n_rows_preprocessed = data_export$n_rows,
    stan_input_paths = stan_input_paths,
    output_paths = output_paths %||% list(
      summary_output = file.path(analysis_spec$paths$outputs_dir, analysis_spec$paths$output_files$summary %||% "summary_output.json"),
      metadata = file.path(analysis_spec$paths$outputs_dir, analysis_spec$paths$output_files$metadata %||% "metadata.json"),
      diagnostics = file.path(analysis_spec$paths$outputs_dir, analysis_spec$paths$output_files$diagnostics %||% "diagnostics.json"),
      prototype_reference_summary = "outputs/prototype_reference_summary.json",
      prototype_cmdstan_comparison = "outputs/prototype_cmdstan_comparison.json"
    ),
    diagnostics_passed = diagnostics_passed,
    outcome_types = unname(analysis_spec$outcome_types),
    engine_package_sync = engine_package_sync,
    error_message = error_message,
    notes = list(
      "This validation uses simulated data aligned with prototype/demo_data_advanced.xlsx or the Rmd prototype simulation logic.",
      "Step 2.5 generation and CmdStan validation reuse spec/analysis_spec.R and config/config.json.",
      "This is migration validation, not new statistical model development.",
      "Full brms-vs-CmdStan numerical comparison is optional in v0.1 and is not inferred unless a real prototype reference summary is available."
    ),
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
}

run_prototype_aligned_validation <- function() {
  generate_config(analysis_spec, path = analysis_spec$paths$config_path)
  data_export <- export_prototype_aligned_data(analysis_spec)

  preprocessed_data <- readRDS(data_export$path)
  stan_input_paths <- generate_all_stan_inputs(
    preprocessed_data,
    analysis_spec,
    output_dir = analysis_spec$paths$data_dir
  )

  write_prototype_reference_placeholder("outputs/prototype_reference_summary.json")

  validation_status <- "cmdstan_not_run"
  output_paths <- NULL
  diagnostics_passed <- NA
  error_message <- NULL
  engine_package_sync <- list()

  tryCatch(
    {
      fits <- run_cmdstan_validation(analysis_spec)
      formatted_outputs <- format_all_outputs(fits, analysis_spec, output_dir = analysis_spec$paths$outputs_dir)
      output_paths <- formatted_outputs[c("summary_output", "metadata", "diagnostics")]
      output_paths$prototype_reference_summary <- "outputs/prototype_reference_summary.json"
      output_paths$prototype_cmdstan_comparison <- "outputs/prototype_cmdstan_comparison.json"
      diagnostics_passed <- formatted_outputs$diagnostics_object$all_diagnostics_passed
      validation_status <- "completed"
      engine_package_sync <- sync_engine_package_from_step25(analysis_spec)
    },
    error = function(error) {
      validation_status <<- "cmdstan_failed"
      error_message <<- paste(
        "CmdStan validation failed:",
        conditionMessage(error),
        "Install/configure cmdstanr and CmdStan, then rerun Rscript R/run_prototype_aligned_validation.R."
      )
      message(error_message)
    }
  )

  compare_prototype_and_cmdstan()

  report <- build_validation_report(
    data_export = data_export,
    stan_input_paths = stan_input_paths,
    output_paths = output_paths,
    diagnostics_passed = diagnostics_passed,
    validation_status = validation_status,
    error_message = error_message,
    engine_package_sync = engine_package_sync
  )
  report_path <- write_validation_report(report)

  message("Generated prototype-aligned validation report: ", report_path)
  invisible(report)
}

tryCatch(
  run_prototype_aligned_validation(),
  error = function(error) {
    stop("Prototype-aligned validation failed before CmdStan execution: ", conditionMessage(error), call. = FALSE)
  }
)
