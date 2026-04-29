select_stan_model <- function(outcome_type, models_dir = "models") {
  outcome_type <- match.arg(outcome_type, c("binary", "continuous", "survival"))

  model_file <- switch(
    outcome_type,
    binary = "binary.stan",
    continuous = "continuous.stan",
    survival = "survival.stan"
  )

  model_path <- file.path(models_dir, model_file)
  if (!file.exists(model_path)) {
    stop("Stan model file not found for outcome '", outcome_type, "': ", model_path, call. = FALSE)
  }

  model_path
}
