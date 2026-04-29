generate_config <- function(analysis_spec, path = "config/config.json") {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to generate config JSON.")
  }

  if (is.null(analysis_spec$model_name) || is.null(analysis_spec$version)) {
    stop("analysis_spec must define model_name and version.")
  }

  config <- list(
    metadata = list(
      config_version = analysis_spec$version,
      created_date = as.character(Sys.Date()),
      description = "Bayesian Borrowing Analysis Configuration generated from spec/analysis_spec.R",
      status = "statistical-design-validation"
    ),
    model = list(
      model_name = analysis_spec$model_name,
      outcome_type = if (length(analysis_spec$outcome_types) > 1) {
        "multi-outcome"
      } else {
        analysis_spec$outcome_types[[1]]
      },
      outcome_types = unname(analysis_spec$outcome_types)
    ),
    borrowing = analysis_spec$borrowing,
    weighting = analysis_spec$weighting,
    survival = analysis_spec$survival,
    mcmc = analysis_spec$mcmc,
    diagnostics = analysis_spec$diagnostics,
    output = analysis_spec$output,
    paths = analysis_spec$paths
  )

  config_dir <- dirname(path)
  if (!dir.exists(config_dir)) {
    dir.create(config_dir, recursive = TRUE, showWarnings = FALSE)
  }

  jsonlite::write_json(config, path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  config
}
