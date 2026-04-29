# Statistical Design Package analysis specification.
#
# Statistical design owners primarily modify this file. The generator scripts
# derive config JSON, Stan input JSON, validation runs, and standard outputs
# from this object.

analysis_spec <- list(
  model_name = "borrowing_v1",
  version = "0.1",

  # Commonly changed by statistical design owners.
  outcome_types = c("binary", "continuous", "survival"),
  borrowing = list(
    method = "fixed_power_prior_weight",
    a0 = 0.5
  ),
  weighting = list(
    use_ps_weight = TRUE,
    trim_lower = 0.01,
    trim_upper = 0.99
  ),
  survival = list(
    cut_points = c(6, 12, 18, 24, 30)
  ),
  mcmc = list(
    chains = 4,
    iter = 2000,
    warmup = 1000,
    seed = 20260407
  ),
  diagnostics = list(
    rhat_threshold = 1.05,
    ess_bulk_min = 400,
    ess_tail_min = 400,
    divergent_allowed = 0,
    stop_on_failure = TRUE
  ),

  # Usually stable unless our workflow layout changes.
  output = list(
    save_warmup = FALSE,
    output_dir = "outputs"
  ),
  paths = list(
    config_path = "config/config.json",
    models_dir = "models",
    data_dir = "data",
    outputs_dir = "outputs",
    cmdstan_output_dir = file.path("outputs", "cmdstan"),
    stan_input_files = list(
      binary = "stan_input_binary.json",
      continuous = "stan_input_continuous.json",
      survival = "stan_input_survival.json"
    ),
    model_files = list(
      binary = "binary.stan",
      continuous = "continuous.stan",
      survival = "survival.stan"
    ),
    output_files = list(
      summary = "summary_output.json",
      metadata = "metadata.json",
      diagnostics = "diagnostics.json"
    )
  )
)
