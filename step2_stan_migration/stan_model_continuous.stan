data {
  int<lower=1> N;
  vector[N] y;
  array[N] int<lower=0, upper=1> trt;
  vector<lower=0>[N] weights;
}

parameters {
  real alpha;
  real beta_trt;
  real<lower=0> sigma;
}

model {
  alpha ~ normal(0, 10);
  beta_trt ~ normal(0, 10);
  sigma ~ student_t(3, 0, 10);

  for (i in 1:N) {
    target += weights[i] * normal_lpdf(y[i] | alpha + beta_trt * trt[i], sigma);
  }
}

generated quantities {
  real mean_difference;
  mean_difference = beta_trt;
}
data {
  int<lower=1> N;
  vector[N] cont_y;
  vector[N] trt;
  vector<lower=0>[N] bayes_w;
}

transformed data {
  real prior_intercept_sd = 10;
  real prior_trt_sd = 10;
  real prior_sigma_df = 3;
  real prior_sigma_scale = 10;
}

parameters {
  real alpha;
  real beta_trt;
  real<lower=0> sigma;
}

transformed parameters {
  vector[N] mu = alpha + beta_trt * trt;
}

model {
  alpha ~ normal(0, prior_intercept_sd);
  beta_trt ~ normal(0, prior_trt_sd);
  sigma ~ student_t(prior_sigma_df, 0, prior_sigma_scale);

  for (n in 1:N) {
    target += bayes_w[n] * normal_lpdf(cont_y[n] | mu[n], sigma);
  }
}

generated quantities {
  real mean_difference = beta_trt;
  vector[N] log_lik;

  for (n in 1:N) {
    log_lik[n] = bayes_w[n] * normal_lpdf(cont_y[n] | mu[n], sigma);
  }
}
