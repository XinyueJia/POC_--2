source("spec/analysis_spec.R")
source("R/run_brms_reference_validation.R")
source("R/compare_prototype_and_cmdstan.R")

mode <- "quick"

ensure_step26_outputs <- function() {
  missing_paths <- c()
  if (!file.exists("data/preprocessed_demo.rds")) {
    missing_paths <- c(missing_paths, "data/preprocessed_demo.rds")
  }
  if (!file.exists("outputs/summary_output.json")) {
    missing_paths <- c(missing_paths, "outputs/summary_output.json")
  }

  if (length(missing_paths) > 0) {
    stop(
      "Step 2.6 outputs are missing: ",
      paste(missing_paths, collapse = ", "),
      ". Run Rscript R/run_prototype_aligned_validation.R first.",
      call. = FALSE
    )
  }
}

run_brms_vs_cmdstan_comparison <- function(mode = c("quick", "full")) {
  mode <- match.arg(mode)
  ensure_step26_outputs()
  run_brms_reference_validation(mode = mode)
  comparison_path <- compare_prototype_and_cmdstan()
  message("Generated brms-vs-CmdStan comparison report: ", comparison_path)
  invisible(comparison_path)
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0 && args[[1]] %in% c("quick", "full")) {
  mode <- args[[1]]
}

tryCatch(
  run_brms_vs_cmdstan_comparison(mode = mode),
  error = function(error) {
    stop("brms-vs-CmdStan comparison failed: ", conditionMessage(error), call. = FALSE)
  }
)
