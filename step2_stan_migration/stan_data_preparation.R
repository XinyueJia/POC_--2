prepare_stan_data <- function(preprocessed_data, outcome_type = c("binary", "continuous", "survival", "multi-outcome"), config) {
  outcome_type <- match.arg(outcome_type)

  if (missing(config) || is.null(config)) {
    stop("config is required for Step 2 data preparation")
  }

  data <- as.data.frame(preprocessed_data)

  required_common <- c("trt")
  missing_common <- setdiff(required_common, names(data))
  if (length(missing_common) > 0) {
    stop("Missing required column(s): ", paste(missing_common, collapse = ", "))
  }

  if (isTRUE(config$weighting$use_ps_weight)) {
    if (!"bayes_w" %in% names(data)) {
      stop("Missing required column 'bayes_w' when use_ps_weight = TRUE")
    }
    weight_column <- "bayes_w"
  } else if ("bayes_w" %in% names(data)) {
    weight_column <- "bayes_w"
  } else if ("weight" %in% names(data)) {
    weight_column <- "weight"
  } else {
    weight_column <- NULL
  }

  common_data <- list(
    N = nrow(data),
    trt = as.integer(data$trt)
  )

  if (!is.null(weight_column)) {
    common_data$weights <- as.numeric(data[[weight_column]])
  } else {
    common_data$weights <- rep(1, nrow(data))
  }

  binary_data <- NULL
  continuous_data <- NULL
  survival_data <- NULL

  if (outcome_type %in% c("binary", "multi-outcome")) {
    if (!"binary_y" %in% names(data)) {
      stop("Missing required column 'binary_y' for binary outcome preparation")
    }
    binary_data <- c(
      common_data,
      list(y = as.integer(data$binary_y))
    )
  }

  if (outcome_type %in% c("continuous", "multi-outcome")) {
    if (!"cont_y" %in% names(data)) {
      stop("Missing required column 'cont_y' for continuous outcome preparation")
    }
    continuous_data <- c(
      common_data,
      list(y = as.numeric(data$cont_y))
    )
  }

  if (outcome_type %in% c("survival", "multi-outcome")) {
    survival_data <- prepare_survival_data(data, config, common_data)
  }

  list(
    outcome_type = outcome_type,
    binary = binary_data,
    continuous = continuous_data,
    survival = survival_data
  )
}

prepare_survival_data <- function(data, config, common_data) {
  cut_points <- config$survival$cut_points
  if (is.null(cut_points) || length(cut_points) == 0) {
    stop("Missing survival cut_points in config")
  }

  if (!all(c("time", "status") %in% names(data))) {
    if (all(c("interval", "exposure", "event_piece") %in% names(data))) {
      survival_data <- c(
        common_data,
        list(
          N = nrow(data),
          interval = as.integer(data$interval),
          exposure = as.numeric(data$exposure),
          event = as.integer(data$event_piece)
        )
      )
      return(survival_data)
    }
    stop("Survival input requires either (time, status) or pre-expanded (interval, exposure, event_piece) columns")
  }

  split_data <- split_survival_rows(data, cut_points)
  c(
    list(
      N = nrow(split_data),
      J = length(cut_points) + 1,
      interval = as.integer(split_data$interval),
      exposure = as.numeric(split_data$exposure),
      event = as.integer(split_data$event_piece),
      trt = as.integer(split_data$trt)
    ),
    if (!is.null(common_data$weights)) list(weights = common_data$weights[split_data$row_id]) else list()
  )
}

split_survival_rows <- function(data, cut_points) {
  if (!requireNamespace("survival", quietly = TRUE)) {
    stop("Package 'survival' is required to split survival data")
  }

  split_df <- survival::survSplit(
    data = data,
    cut = cut_points,
    end = "time",
    event = "status",
    start = "start",
    id = "row_id"
  )

  split_df$exposure <- split_df$time - split_df$start
  split_df$event_piece <- as.integer(split_df$status)
  split_df$interval <- as.integer(ave(split_df$row_id, split_df$row_id, FUN = seq_along))
  split_df
}
