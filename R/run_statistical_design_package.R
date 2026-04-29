source("spec/analysis_spec.R")
source("R/generate_config.R")
source("R/generate_stan_data.R")
source("R/select_stan_model.R")
source("R/run_cmdstan_validation.R")
source("R/format_outputs.R")

create_synthetic_preprocessed_data <- function(n = 60, seed = 20260407) {
  set.seed(seed)
  trt <- rbinom(n, 1, 0.5)
  bayes_w <- ifelse(trt == 1, 0.95, 0.55)
  linear_binary <- -0.2 - 0.8 * trt
  binary_y <- rbinom(n, 1, plogis(linear_binary))
  cont_y <- 55 - 6 * trt + stats::rnorm(n, 0, 5)
  event_rate <- 0.075 * exp(-0.55 * trt)
  event_time <- stats::rexp(n, rate = event_rate)
  censor_time <- stats::runif(n, min = 12, max = 36)
  time <- pmax(0.25, pmin(event_time, censor_time))
  status <- as.integer(event_time <= censor_time)

  data.frame(
    trt = trt,
    bayes_w = bayes_w,
    binary_y = binary_y,
    cont_y = cont_y,
    time = time,
    status = status
  )
}

load_or_create_preprocessed_data <- function(analysis_spec) {
  demo_rds <- file.path(analysis_spec$paths$data_dir, "preprocessed_demo.rds")
  if (file.exists(demo_rds)) {
    data <- readRDS(demo_rds)
    return(as.data.frame(data))
  }

  create_synthetic_preprocessed_data(seed = analysis_spec$mcmc$seed)
}

main <- function() {
  config_path <- analysis_spec$paths$config_path
  data_dir <- analysis_spec$paths$data_dir
  output_dir <- analysis_spec$paths$outputs_dir

  generate_config(analysis_spec, path = config_path)

  preprocessed_data <- load_or_create_preprocessed_data(analysis_spec)
  stan_input_paths <- generate_all_stan_inputs(preprocessed_data, analysis_spec, output_dir = data_dir)

  fits <- run_cmdstan_validation(analysis_spec)
  output_paths <- format_all_outputs(fits, analysis_spec, output_dir = output_dir)

  message("Generated config: ", config_path)
  message("Generated Stan inputs:")
  for (path in stan_input_paths) {
    message("  - ", path)
  }
  message("Generated outputs:")
  message("  - ", output_paths$summary_output)
  message("  - ", output_paths$metadata)
  message("  - ", output_paths$diagnostics)

  invisible(list(
    config_path = config_path,
    stan_input_paths = stan_input_paths,
    output_paths = output_paths
  ))
}

tryCatch(
  main(),
  error = function(error) {
    stop("Statistical Design Package run failed: ", conditionMessage(error), call. = FALSE)
  }
)
