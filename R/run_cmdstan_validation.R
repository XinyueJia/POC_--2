build_design_run_id <- function(analysis_spec) {
  paste0(analysis_spec$model_name, "_", format(Sys.time(), "%Y%m%d_%H%M%S"))
}

stan_input_path_for <- function(outcome_type, analysis_spec) {
  data_dir <- if (!is.null(analysis_spec$paths$data_dir)) analysis_spec$paths$data_dir else "data"
  input_file <- analysis_spec$paths$stan_input_files[[outcome_type]]
  if (is.null(input_file)) {
    input_file <- paste0("stan_input_", outcome_type, ".json")
  }
  file.path(data_dir, input_file)
}

run_cmdstan_validation <- function(analysis_spec, outcome_types = analysis_spec$outcome_types) {
  if (!requireNamespace("cmdstanr", quietly = TRUE)) {
    stop(
      "Package 'cmdstanr' is required for CmdStan validation. ",
      "Install cmdstanr and configure CmdStan before running validation.",
      call. = FALSE
    )
  }

  models_dir <- if (!is.null(analysis_spec$paths$models_dir)) analysis_spec$paths$models_dir else "models"
  cmdstan_root <- if (!is.null(analysis_spec$paths$cmdstan_output_dir)) {
    analysis_spec$paths$cmdstan_output_dir
  } else {
    file.path(analysis_spec$output$output_dir, "cmdstan")
  }
  run_id <- build_design_run_id(analysis_spec)

  fits <- list()
  run_paths <- list()
  model_paths <- list()
  stan_input_paths <- list()

  for (outcome_type in outcome_types) {
    model_path <- select_stan_model(outcome_type, models_dir = models_dir)
    stan_input_path <- stan_input_path_for(outcome_type, analysis_spec)
    if (!file.exists(stan_input_path)) {
      stop("Stan input JSON not found for outcome '", outcome_type, "': ", stan_input_path, call. = FALSE)
    }

    outcome_output_dir <- file.path(cmdstan_root, run_id, outcome_type)
    if (!dir.exists(outcome_output_dir)) {
      dir.create(outcome_output_dir, recursive = TRUE, showWarnings = FALSE)
    }

    detected_cores <- parallel::detectCores()
    if (is.na(detected_cores) || detected_cores < 1) {
      detected_cores <- 1L
    }

    model <- cmdstanr::cmdstan_model(model_path)
    fit <- model$sample(
      data = stan_input_path,
      chains = analysis_spec$mcmc$chains,
      parallel_chains = min(analysis_spec$mcmc$chains, detected_cores),
      iter_warmup = analysis_spec$mcmc$warmup,
      iter_sampling = analysis_spec$mcmc$iter - analysis_spec$mcmc$warmup,
      seed = analysis_spec$mcmc$seed,
      output_dir = outcome_output_dir,
      save_warmup = isTRUE(analysis_spec$output$save_warmup)
    )

    fits[[outcome_type]] <- fit
    run_paths[[outcome_type]] <- outcome_output_dir
    model_paths[[outcome_type]] <- model_path
    stan_input_paths[[outcome_type]] <- stan_input_path
  }

  structure(
    list(
      fits = fits,
      run_paths = run_paths,
      run_metadata = list(
        run_id = run_id,
        model_name = analysis_spec$model_name,
        analysis_spec_version = analysis_spec$version,
        generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
        config_path = if (!is.null(analysis_spec$paths$config_path)) analysis_spec$paths$config_path else "config/config.json",
        stan_input_paths = stan_input_paths,
        model_paths = model_paths,
        cmdstan_run_paths = run_paths
      )
    ),
    class = "statistical_design_validation"
  )
}
