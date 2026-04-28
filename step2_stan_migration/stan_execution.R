read_step2_config <- function(config_path = "config/config.json") {
  if (!file.exists(config_path)) {
    stop("Config file not found: ", config_path)
  }

  config <- jsonlite::read_json(config_path, simplifyVector = TRUE)
  config$config_path <- config_path
  config
}

build_step2_run_id <- function(model_name) {
  paste0(model_name, "_", format(Sys.time(), "%Y%m%d_%H%M%S"))
}

run_stan_workflow <- function(stan_file, stan_data, config_path = "config/config.json") {
  if (!file.exists(stan_file)) {
    stop("Stan file not found: ", stan_file)
  }

  if (!is.list(stan_data)) {
    stop("stan_data must be a list produced by prepare_stan_data()")
  }

  config <- read_step2_config(config_path)
  model_name <- config$model$model_name
  run_id <- build_step2_run_id(model_name)
  output_root <- config$output$output_dir
  run_output_dir <- file.path(output_root, run_id)

  if (!dir.exists(run_output_dir)) {
    dir.create(run_output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  run_spec <- list(
    run_id = run_id,
    model_name = model_name,
    stan_file = normalizePath(stan_file, winslash = "/"),
    output_dir = normalizePath(run_output_dir, winslash = "/"),
    chains = config$mcmc$chains,
    iter = config$mcmc$iter,
    warmup = config$mcmc$warmup,
    seed = config$mcmc$seed,
    save_warmup = isTRUE(config$output$save_warmup),
    stan_data = stan_data
  )

  if (!requireNamespace("cmdstanr", quietly = TRUE)) {
    stop("Package 'cmdstanr' is required to run Step 2 Stan workflows")
  }

  stan_model <- cmdstanr::cmdstan_model(stan_file)
  fit <- stan_model$sample(
    data = stan_data,
    chains = config$mcmc$chains,
    parallel_chains = min(config$mcmc$chains, parallel::detectCores()),
    iter_warmup = config$mcmc$warmup,
    iter_sampling = config$mcmc$iter - config$mcmc$warmup,
    seed = config$mcmc$seed,
    output_dir = run_output_dir,
    save_warmup = isTRUE(config$output$save_warmup)
  )

  list(
    run_spec = run_spec,
    fit = fit,
    config = config
  )
}
