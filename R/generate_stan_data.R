required_columns <- function(data, columns, context) {
  missing_columns <- setdiff(columns, names(data))
  if (length(missing_columns) > 0) {
    stop(
      context,
      " requires missing column(s): ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }
}

select_weight_vector <- function(data, analysis_spec) {
  if (isTRUE(analysis_spec$weighting$use_ps_weight)) {
    required_columns(data, "bayes_w", "PS-weighted Stan data")
    return(as.numeric(data$bayes_w))
  }

  if ("bayes_w" %in% names(data)) {
    return(as.numeric(data$bayes_w))
  }
  if ("weight" %in% names(data)) {
    return(as.numeric(data$weight))
  }

  rep(1, nrow(data))
}

prepare_stan_data <- function(preprocessed_data, outcome_type, analysis_spec) {
  outcome_type <- match.arg(outcome_type, c("binary", "continuous", "survival"))
  data <- as.data.frame(preprocessed_data)

  required_columns(data, "trt", paste0(outcome_type, " Stan data"))
  weights <- select_weight_vector(data, analysis_spec)

  if (outcome_type == "binary") {
    required_columns(data, "binary_y", "Binary Stan data")
    return(list(
      N = nrow(data),
      y = as.integer(data$binary_y),
      trt = as.integer(data$trt),
      weights = weights
    ))
  }

  if (outcome_type == "continuous") {
    required_columns(data, "cont_y", "Continuous Stan data")
    return(list(
      N = nrow(data),
      y = as.numeric(data$cont_y),
      trt = as.integer(data$trt),
      weights = weights
    ))
  }

  prepare_survival_stan_data(data, analysis_spec, weights)
}

prepare_survival_stan_data <- function(data, analysis_spec, weights) {
  cut_points <- analysis_spec$survival$cut_points
  if (is.null(cut_points) || length(cut_points) == 0) {
    stop("Survival Stan data requires analysis_spec$survival$cut_points.", call. = FALSE)
  }

  if (all(c("event", "interval", "exposure") %in% names(data))) {
    required_columns(data, c("trt", "event", "interval", "exposure"), "Pre-split survival Stan data")
    return(list(
      N = nrow(data),
      J = max(as.integer(data$interval), length(cut_points) + 1),
      event = as.integer(data$event),
      interval = as.integer(data$interval),
      trt = as.integer(data$trt),
      exposure = as.numeric(data$exposure),
      weights = weights
    ))
  }

  required_columns(data, c("time", "status"), "Survival Stan data")
  if (!requireNamespace("survival", quietly = TRUE)) {
    stop("Package 'survival' is required to split survival data.", call. = FALSE)
  }

  data$.design_source_row <- seq_len(nrow(data))
  split_data <- survival::survSplit(
    data = data,
    cut = cut_points,
    end = "time",
    event = "status",
    start = "start",
    id = ".design_split_id"
  )

  split_data$exposure <- split_data$time - split_data$start
  split_data$event <- as.integer(split_data$status)
  split_data$interval <- findInterval(split_data$start, cut_points) + 1L
  split_data$interval <- pmax(1L, pmin(as.integer(split_data$interval), length(cut_points) + 1L))

  list(
    N = nrow(split_data),
    J = length(cut_points) + 1L,
    event = as.integer(split_data$event),
    interval = as.integer(split_data$interval),
    trt = as.integer(split_data$trt),
    exposure = as.numeric(split_data$exposure),
    weights = as.numeric(weights[split_data$.design_source_row])
  )
}

generate_stan_input_json <- function(preprocessed_data, outcome_type, analysis_spec, output_path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to generate Stan input JSON.")
  }

  stan_data <- prepare_stan_data(preprocessed_data, outcome_type, analysis_spec)
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  jsonlite::write_json(stan_data, output_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
  invisible(output_path)
}

stan_input_filename <- function(outcome_type, analysis_spec) {
  spec_file <- analysis_spec$paths$stan_input_files[[outcome_type]]
  if (!is.null(spec_file)) {
    return(spec_file)
  }
  paste0("stan_input_", outcome_type, ".json")
}

generate_all_stan_inputs <- function(preprocessed_data, analysis_spec, output_dir = "data") {
  if (!is.null(analysis_spec$paths$data_dir) && missing(output_dir)) {
    output_dir <- analysis_spec$paths$data_dir
  }

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  paths <- list()
  for (outcome_type in analysis_spec$outcome_types) {
    output_path <- file.path(output_dir, stan_input_filename(outcome_type, analysis_spec))
    generate_stan_input_json(preprocessed_data, outcome_type, analysis_spec, output_path)
    paths[[outcome_type]] <- output_path
  }

  paths
}
